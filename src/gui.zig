const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Color = enum { white, black };
const PieceKind = enum { pawn, knight, bishop, rook, queen, king };
const Piece = struct { kind: PieceKind, color: Color };
const Move = struct {
    from: u8,
    to: u8,
    promotion: ?PieceKind = null,
    is_en_passant: bool = false,
    is_castle: bool = false,
};
const CastlingRights = packed struct {
    white_k: bool = true,
    white_q: bool = true,
    black_k: bool = true,
    black_q: bool = true,
};
const State = struct {
    board: [64]?Piece,
    side_to_move: Color = .white,
    castling: CastlingRights = .{},
    en_passant: ?u8 = null,
    halfmove: u16 = 0,
    fullmove: u16 = 1,
    wk_pos: u8 = 60,
    bk_pos: u8 = 4,
};
const MoveList = std.ArrayListUnmanaged(Move);

fn sq(file: u8, rank: u8) u8 {
    return rank * 8 + file;
}
fn fileOf(idx: u8) u8 {
    return idx % 8;
}
fn rankOf(idx: u8) u8 {
    return idx / 8;
}
fn otherColor(c0: Color) Color {
    return if (c0 == .white) .black else .white;
}
fn inBounds(file: i32, rank: i32) bool {
    return file >= 0 and file < 8 and rank >= 0 and rank < 8;
}

fn initBoard() State {
    var s = State{
        .board = [_]?Piece{null} ** 64,
        .side_to_move = .white,
        .castling = .{},
        .en_passant = null,
        .halfmove = 0,
        .fullmove = 1,
        .wk_pos = 60,
        .bk_pos = 4,
    };
    const back: [8]PieceKind = .{ .rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook };
    var f: usize = 0;
    while (f < 8) : (f += 1) {
        s.board[sq(@intCast(f), 0)] = Piece{ .kind = back[f], .color = .white };
        s.board[sq(@intCast(f), 1)] = Piece{ .kind = .pawn, .color = .white };
        s.board[sq(@intCast(f), 6)] = Piece{ .kind = .pawn, .color = .black };
        s.board[sq(@intCast(f), 7)] = Piece{ .kind = back[f], .color = .black };
    }
    s.wk_pos = sq(4, 0);
    s.bk_pos = sq(4, 7);
    return s;
}

fn attacksFrom(s: *const State, from: u8, p: Piece, target: u8) bool {
    const f: i32 = @intCast(fileOf(from));
    const r: i32 = @intCast(rankOf(from));
    const tf: i32 = @intCast(fileOf(target));
    const tr: i32 = @intCast(rankOf(target));
    switch (p.kind) {
        .pawn => {
            const dir: i32 = if (p.color == .white) 1 else -1;
            if (tf == f + 1 and tr == r + dir) return true;
            if (tf == f - 1 and tr == r + dir) return true;
            return false;
        },
        .knight => {
            const df: i32 = if (tf > f) tf - f else f - tf;
            const dr: i32 = if (tr > r) tr - r else r - tr;
            return (df == 1 and dr == 2) or (df == 2 and dr == 1);
        },
        .bishop => {
            const df: i32 = if (tf > f) tf - f else f - tf;
            const dr: i32 = if (tr > r) tr - r else r - tr;
            if (df != dr) return false;
            const step_f: i32 = if (tf > f) 1 else -1;
            const step_r: i32 = if (tr > r) 1 else -1;
            var cf = f + step_f;
            var cr = r + step_r;
            while (cf != tf and cr != tr) : ({
                cf += step_f;
                cr += step_r;
            }) {
                const idx: u8 = @intCast(cr * 8 + cf);
                if (s.board[idx] != null) return false;
            }
            return true;
        },
        .rook => {
            if (tf != f and tr != r) return false;
            if (tf == f) {
                const step: i32 = if (tr > r) 1 else -1;
                var cr = r + step;
                while (cr != tr) : (cr += step) {
                    const idx: u8 = @intCast(cr * 8 + f);
                    if (s.board[idx] != null) return false;
                }
                return true;
            } else {
                const step: i32 = if (tf > f) 1 else -1;
                var cf = f + step;
                while (cf != tf) : (cf += step) {
                    const idx: u8 = @intCast(r * 8 + cf);
                    if (s.board[idx] != null) return false;
                }
                return true;
            }
        },
        .queen => {
            const rook_like = Piece{ .kind = .rook, .color = p.color };
            const bishop_like = Piece{ .kind = .bishop, .color = p.color };
            return attacksFrom(s, from, rook_like, target) or attacksFrom(s, from, bishop_like, target);
        },
        .king => {
            const df: i32 = if (tf > f) tf - f else f - tf;
            const dr: i32 = if (tr > r) tr - r else r - tr;
            return df <= 1 and dr <= 1 and !(df == 0 and dr == 0);
        },
    }
}
fn attackedByColor(s: *const State, target: u8, color: Color) bool {
    var idx: u8 = 0;
    while (idx < 64) : (idx += 1) {
        if (s.board[idx]) |p| {
            if (p.color != color) continue;
            if (attacksFrom(s, idx, p, target)) return true;
        }
    }
    return false;
}

fn addMove(buf: *MoveList, allocator: std.mem.Allocator, m: Move) !void {
    try buf.append(allocator, m);
}

fn genLine(s: *const State, idx: u8, p: Piece, dirs: []const [2]i8, king_step_only: bool, moves: *MoveList, allocator: std.mem.Allocator) !void {
    const f0: i32 = @intCast(fileOf(idx));
    const r0: i32 = @intCast(rankOf(idx));
    for (dirs) |dir| {
        var f = f0 + dir[0];
        var r = r0 + dir[1];
        while (inBounds(f, r)) {
            const nidx: u8 = @intCast(r * 8 + f);
            if (s.board[nidx]) |q| {
                if (q.color != p.color) try addMove(moves, allocator, Move{ .from = idx, .to = nidx });
                break;
            } else {
                try addMove(moves, allocator, Move{ .from = idx, .to = nidx });
            }
            if (king_step_only) break;
            f += dir[0];
            r += dir[1];
        }
    }
}
fn genKnight(s: *const State, idx: u8, p: Piece, moves: *MoveList, allocator: std.mem.Allocator) !void {
    const jumps = [_][2]i8{
        .{ 1, 2 }, .{ 2, 1 }, .{ -1, 2 }, .{ -2, 1 }, .{ 1, -2 }, .{ 2, -1 }, .{ -1, -2 }, .{ -2, -1 },
    };
    const f0: i32 = @intCast(fileOf(idx));
    const r0: i32 = @intCast(rankOf(idx));
    for (jumps) |j| {
        const f = f0 + j[0];
        const r = r0 + j[1];
        if (!inBounds(f, r)) continue;
        const nidx: u8 = @intCast(r * 8 + f);
        if (s.board[nidx]) |q| {
            if (q.color != p.color) try addMove(moves, allocator, Move{ .from = idx, .to = nidx });
        } else {
            try addMove(moves, allocator, Move{ .from = idx, .to = nidx });
        }
    }
}
fn genPawnMoves(s: *const State, idx: u8, p: Piece, moves: *MoveList, allocator: std.mem.Allocator) !void {
    const f: i32 = @intCast(fileOf(idx));
    const r: i32 = @intCast(rankOf(idx));
    const dir: i32 = if (p.color == .white) 1 else -1;
    const start_rank: i32 = if (p.color == .white) 1 else 6;
    const promo_rank: i32 = if (p.color == .white) 6 else 1;
    const one_ahead_r = r + dir;
    if (inBounds(f, one_ahead_r)) {
        const one_idx: u8 = @intCast(one_ahead_r * 8 + f);
        if (s.board[one_idx] == null) {
            if (r == promo_rank) {
                try addMove(moves, allocator, Move{ .from = idx, .to = one_idx, .promotion = .queen });
                try addMove(moves, allocator, Move{ .from = idx, .to = one_idx, .promotion = .rook });
                try addMove(moves, allocator, Move{ .from = idx, .to = one_idx, .promotion = .bishop });
                try addMove(moves, allocator, Move{ .from = idx, .to = one_idx, .promotion = .knight });
            } else {
                try addMove(moves, allocator, Move{ .from = idx, .to = one_idx });
                if (r == start_rank) {
                    const two_idx: u8 = @intCast((r + 2 * dir) * 8 + f);
                    if (s.board[two_idx] == null) {
                        try addMove(moves, allocator, Move{ .from = idx, .to = two_idx });
                    }
                }
            }
        }
    }
    var df: i32 = -1;
    while (df <= 1) : (df += 2) {
        const cf = f + df;
        const cr = r + dir;
        if (!inBounds(cf, cr)) continue;
        const cidx: u8 = @intCast(cr * 8 + cf);
        if (s.board[cidx]) |cap| {
            if (cap.color != p.color) {
                if (r == promo_rank) {
                    try addMove(moves, allocator, Move{ .from = idx, .to = cidx, .promotion = .queen });
                    try addMove(moves, allocator, Move{ .from = idx, .to = cidx, .promotion = .rook });
                    try addMove(moves, allocator, Move{ .from = idx, .to = cidx, .promotion = .bishop });
                    try addMove(moves, allocator, Move{ .from = idx, .to = cidx, .promotion = .knight });
                } else {
                    try addMove(moves, allocator, Move{ .from = idx, .to = cidx });
                }
            }
        } else if (s.en_passant) |ep| {
            if (ep == cidx) {
                try addMove(moves, allocator, Move{ .from = idx, .to = cidx, .is_en_passant = true });
            }
        }
    }
}
fn genKing(s: *const State, idx: u8, p: Piece, moves: *MoveList, allocator: std.mem.Allocator) !void {
    const dirs = [_][2]i8{
        .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 }, .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 },
    };
    try genLine(s, idx, p, &dirs, true, moves, allocator);
    if (p.color == .white) {
        if (s.castling.white_k) {
            if (s.board[sq(5, 0)] == null and s.board[sq(6, 0)] == null) {
                if (!attackedByColor(s, sq(4, 0), .black) and !attackedByColor(s, sq(5, 0), .black) and !attackedByColor(s, sq(6, 0), .black)) {
                    try addMove(moves, allocator, Move{ .from = idx, .to = sq(6, 0), .is_castle = true });
                }
            }
        }
        if (s.castling.white_q) {
            if (s.board[sq(1, 0)] == null and s.board[sq(2, 0)] == null and s.board[sq(3, 0)] == null) {
                if (!attackedByColor(s, sq(4, 0), .black) and !attackedByColor(s, sq(3, 0), .black) and !attackedByColor(s, sq(2, 0), .black)) {
                    try addMove(moves, allocator, Move{ .from = idx, .to = sq(2, 0), .is_castle = true });
                }
            }
        }
    } else {
        if (s.castling.black_k) {
            if (s.board[sq(5, 7)] == null and s.board[sq(6, 7)] == null) {
                if (!attackedByColor(s, sq(4, 7), .white) and !attackedByColor(s, sq(5, 7), .white) and !attackedByColor(s, sq(6, 7), .white)) {
                    try addMove(moves, allocator, Move{ .from = idx, .to = sq(6, 7), .is_castle = true });
                }
            }
        }
        if (s.castling.black_q) {
            if (s.board[sq(1, 7)] == null and s.board[sq(2, 7)] == null and s.board[sq(3, 7)] == null) {
                if (!attackedByColor(s, sq(4, 7), .white) and !attackedByColor(s, sq(3, 7), .white) and !attackedByColor(s, sq(2, 7), .white)) {
                    try addMove(moves, allocator, Move{ .from = idx, .to = sq(2, 7), .is_castle = true });
                }
            }
        }
    }
}
fn generatePseudoLegal(s: *const State, color: Color, moves: *MoveList, allocator: std.mem.Allocator) !void {
    var idx: u8 = 0;
    while (idx < 64) : (idx += 1) {
        if (s.board[idx]) |p| {
            if (p.color != color) continue;
            switch (p.kind) {
                .pawn => try genPawnMoves(s, idx, p, moves, allocator),
                .knight => try genKnight(s, idx, p, moves, allocator),
                .bishop => {
                    const dirs = [_][2]i8{ .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 } };
                    try genLine(s, idx, p, &dirs, false, moves, allocator);
                },
                .rook => {
                    const dirs = [_][2]i8{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
                    try genLine(s, idx, p, &dirs, false, moves, allocator);
                },
                .queen => {
                    const dirs = [_][2]i8{
                        .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 }, .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 },
                    };
                    try genLine(s, idx, p, &dirs, false, moves, allocator);
                },
                .king => try genKing(s, idx, p, moves, allocator),
            }
        }
    }
}
fn legalMoves(s: *State, allocator: std.mem.Allocator) !MoveList {
    var list: MoveList = .{};
    var pseudo: MoveList = .{};
    defer pseudo.deinit(allocator);
    try generatePseudoLegal(s, s.side_to_move, &pseudo, allocator);
    var i: usize = 0;
    while (i < pseudo.items.len) : (i += 1) {
        const m = pseudo.items[i];
        const snapshot = s.*;
        makeMove(s, m);
        const king_sq: u8 = if (snapshot.side_to_move == .white) s.wk_pos else s.bk_pos;
        const in_check = attackedByColor(s, king_sq, otherColor(snapshot.side_to_move));
        if (!in_check) {
            try list.append(allocator, m);
        }
        s.* = snapshot;
    }
    return list;
}
fn makeMove(s: *State, m: Move) void {
    const moving = s.board[m.from].?;
    if (moving.kind == .king) {
        if (moving.color == .white) {
            s.castling.white_k = false;
            s.castling.white_q = false;
            s.wk_pos = m.to;
        } else {
            s.castling.black_k = false;
            s.castling.black_q = false;
            s.bk_pos = m.to;
        }
        if (m.is_castle) {
            if (moving.color == .white) {
                if (m.to == sq(6, 0)) {
                    s.board[sq(5, 0)] = s.board[sq(7, 0)];
                    s.board[sq(7, 0)] = null;
                } else if (m.to == sq(2, 0)) {
                    s.board[sq(3, 0)] = s.board[sq(0, 0)];
                    s.board[sq(0, 0)] = null;
                }
            } else {
                if (m.to == sq(6, 7)) {
                    s.board[sq(5, 7)] = s.board[sq(7, 7)];
                    s.board[sq(7, 7)] = null;
                } else if (m.to == sq(2, 7)) {
                    s.board[sq(3, 7)] = s.board[sq(0, 7)];
                    s.board[sq(0, 7)] = null;
                }
            }
        }
    }
    if (moving.kind == .rook) {
        if (m.from == sq(0, 0)) s.castling.white_q = false;
        if (m.from == sq(7, 0)) s.castling.white_k = false;
        if (m.from == sq(0, 7)) s.castling.black_q = false;
        if (m.from == sq(7, 7)) s.castling.black_k = false;
    }
    if (m.is_en_passant) {
        if (moving.color == .white) {
            const cap_idx = m.to - 8;
            s.board[cap_idx] = null;
        } else {
            const cap_idx = m.to + 8;
            s.board[cap_idx] = null;
        }
    }
    s.board[m.to] = moving;
    s.board[m.from] = null;
    if (m.promotion) |pk| {
        s.board[m.to] = Piece{ .kind = pk, .color = moving.color };
    }
    const r_from: u8 = rankOf(m.from);
    const r_to: u8 = rankOf(m.to);
    const pawn_double: bool = moving.kind == .pawn and (if (r_to > r_from) r_to - r_from else r_from - r_to) == 2;
    if (pawn_double) {
        const ep_rank: u8 = if (moving.color == .white) r_from + 1 else r_from - 1;
        s.en_passant = sq(fileOf(m.from), ep_rank);
    } else {
        s.en_passant = null;
    }
    s.halfmove = if (moving.kind == .pawn or (s.board[m.to] != null and s.board[m.to].?.color != moving.color)) 0 else s.halfmove + 1;
    if (s.side_to_move == .black) s.fullmove += 1;
    s.side_to_move = otherColor(s.side_to_move);
}
fn evaluateMaterial(s: *const State) i32 {
    var score: i32 = 0;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        if (s.board[i]) |p| {
            const val: i32 = switch (p.kind) {
                .pawn => 100,
                .knight => 320,
                .bishop => 330,
                .rook => 500,
                .queen => 900,
                .king => 0,
            };
            score += if (p.color == .white) val else -val;
        }
    }
    return score;
}
fn chooseAIMove(s: *State, allocator: std.mem.Allocator) !?Move {
    var moves = try legalMoves(s, allocator);
    defer moves.deinit(allocator);
    if (moves.items.len == 0) return null;
    var best_idx: usize = 0;
    var best_score: i32 = -2147483648;
    var i: usize = 0;
    while (i < moves.items.len) : (i += 1) {
        const m = moves.items[i];
        const snapshot = s.*;
        makeMove(s, m);
        var score = evaluateMaterial(s);
        if (s.side_to_move == .black) score = -score;
        s.* = snapshot;
        if (score > best_score) {
            best_score = score;
            best_idx = i;
        }
    }
    return moves.items[best_idx];
}

fn drawSquare(renderer: *c.SDL_Renderer, x: i32, y: i32, size: i32, r: u8, g: u8, b: u8) void {
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, 255);
    var rect = c.SDL_Rect{ .x = x, .y = y, .w = size, .h = size };
    _ = c.SDL_RenderFillRect(renderer, &rect);
}

// Very small 6x6 bitmap glyphs for piece letters (KQRBNP).
// Each glyph is 6 rows of 6 bits packed into u8.
const Glyph = struct { rows: [6]u8 };
fn bit(b: u8, idx: u3) bool {
    return ((b >> (5 - idx)) & 1) == 1;
}
const Glyphs = struct {
    pub const K = Glyph{ .rows = .{ 0b100001, 0b100010, 0b111100, 0b100010, 0b100001, 0b100001 } };
    pub const Q = Glyph{ .rows = .{ 0b011110, 0b100001, 0b101101, 0b100001, 0b100001, 0b011110 } };
    pub const R = Glyph{ .rows = .{ 0b111110, 0b100001, 0b111110, 0b101000, 0b100100, 0b100010 } };
    pub const B = Glyph{ .rows = .{ 0b111100, 0b100010, 0b111100, 0b100010, 0b100010, 0b111100 } };
    pub const N = Glyph{ .rows = .{ 0b100001, 0b110001, 0b101001, 0b100101, 0b100011, 0b100001 } };
    pub const P = Glyph{ .rows = .{ 0b111110, 0b100001, 0b111110, 0b100000, 0b100000, 0b100000 } };
};

fn drawGlyph(renderer: *c.SDL_Renderer, gx: i32, gy: i32, size: i32, gph: Glyph, r: u8, g: u8, b: u8) void {
    const scale = @divTrunc(size, 8);
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, 255);
    var row: usize = 0;
    while (row < 6) : (row += 1) {
        const bits = gph.rows[row];
        var col: u3 = 0;
        while (col < 6) : (col += 1) {
            if (bit(bits, col)) {
                var py: i32 = 0;
                while (py < scale) : (py += 1) {
                    var px: i32 = 0;
                    while (px < scale) : (px += 1) {
                        _ = c.SDL_RenderDrawPoint(renderer, gx + @as(i32, @intCast(col)) * scale + px + scale, gy + @as(i32, @intCast(row)) * scale + py + scale);
                    }
                }
            }
        }
    }
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        return error.Unexpected;
    }
    defer c.SDL_Quit();

    const tile: i32 = 80;
    const board_px: i32 = tile * 8;
    const win_w: i32 = board_px;
    const win_h: i32 = board_px;
    const window = c.SDL_CreateWindow("chezzig-gui", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, win_w, win_h, 0) orelse return error.Unexpected;
    defer c.SDL_DestroyWindow(window);
    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC) orelse return error.Unexpected;
    defer c.SDL_DestroyRenderer(renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var s = initBoard();
    const human_plays: Color = .white;
    var selected: ?u8 = null;
    var running = true;

    while (running) {
        var evt: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&evt) == 1) {
            switch (evt.type) {
                c.SDL_QUIT => running = false,
                c.SDL_MOUSEBUTTONDOWN => {
                    const mx: i32 = evt.button.x;
                    const my: i32 = evt.button.y;
                    const file = @as(u8, @intCast(@divTrunc(mx, tile)));
                    const rank = @as(u8, @intCast(@divTrunc(my, tile)));
                    if (file < 8 and rank < 8) {
                        const idx = sq(file, @as(u8, @intCast(rank)));
                        if (selected == null) {
                            if (s.board[idx]) |p| {
                                if (p.color == s.side_to_move and p.color == human_plays) {
                                    selected = idx;
                                }
                            }
                        } else {
                            const from = selected.?;
                            selected = null;
                            var moves = try legalMoves(&s, allocator);
                            defer moves.deinit(allocator);
                            var i: usize = 0;
                            var done = false;
                            while (i < moves.items.len) : (i += 1) {
                                const m = moves.items[i];
                                if (m.from == from and m.to == idx) {
                                    makeMove(&s, m);
                                    done = true;
                                    break;
                                }
                            }
                            if (!done) {
                                // Keep selection if clicked own piece
                                if (s.board[idx]) |p2| {
                                    if (p2.color == s.side_to_move and p2.color == human_plays) {
                                        selected = idx;
                                    }
                                }
                            }
                        }
                    }
                },
                c.SDL_KEYDOWN => {
                    if (evt.key.keysym.sym == c.SDLK_ESCAPE) running = false;
                },
                else => {},
            }
        }

        if (s.side_to_move != human_plays) {
            if (try chooseAIMove(&s, allocator)) |m| {
                makeMove(&s, m);
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 255);
        _ = c.SDL_RenderClear(renderer);

        var r: u8 = 0;
        while (r < 8) : (r += 1) {
            var f: u8 = 0;
            while (f < 8) : (f += 1) {
                const x = @as(i32, f) * tile;
                const y = @as(i32, r) * tile;
                const light = (@mod(@as(i32, f) + @as(i32, r), 2) == 0);
                if (light) drawSquare(renderer, x, y, tile, 230, 230, 230) else drawSquare(renderer, x, y, tile, 120, 120, 120);
                const idx = sq(f, r);
                if (selected) |sel| {
                    if (sel == idx) {
                        drawSquare(renderer, x, y, tile, 200, 180, 40);
                    }
                }
                if (s.board[idx]) |p| {
                    const glyph = switch (p.kind) {
                        .king => Glyphs.K,
                        .queen => Glyphs.Q,
                        .rook => Glyphs.R,
                        .bishop => Glyphs.B,
                        .knight => Glyphs.N,
                        .pawn => Glyphs.P,
                    };
                    const col: u8 = if (p.color == .white) 20 else 240;
                    drawGlyph(renderer, x, y, tile, glyph, col, col, col);
                }
            }
        }
        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(10);
    }
}
