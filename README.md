# Chezzig - Zig Chess Game

![Zig Version](https://img.shields.io/badge/Zig-0.15.x-orange?logo=zig&style=for-the-badge) ![Build](https://img.shields.io/badge/build-zig%20build-informational?style=for-the-badge) ![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey?style=for-the-badge) ![GUI](https://img.shields.io/badge/GUI-SDL2-blue?style=for-the-badge)

Modern, minimal chess written in Zig with both a command‑line interface and an SDL2 GUI. It includes full legal move generation, check detection, castling, en passant, promotion, and a simple material‑based AI.

## Features

- Full move rules: pawns (double push, captures, en passant), knights, bishops, rooks, queen, king
- Castling with square safety checks and rook movement
- Promotion to queen/rook/bishop/knight
- Legality filter: rejects moves that leave your king in check
- Checkmate and stalemate detection
- Simple AI that selects the move with the best material outcome
- Clean terminal board with ASCII grid and tiny piece glyphs
- Optional GUI (SDL2) with click‑to‑move and tiny bitmap glyph rendering

## Quick Start

1. Prerequisites

- Zig 0.15.x

2. Build (CLI)

```bash
zig build
```

3. Run (CLI)

```bash
zig build run
```

### GUI (SDL2)

1. Install SDL2

- macOS (Homebrew): `brew install sdl2`
- Linux: install your distro’s SDL2 dev package (e.g., `libsdl2-dev`)

2. Build and run the GUI

```bash
zig build
zig build run-gui
```

## Usage

- Enter moves using coordinate notation: e2e4, g8f6, e7e8q
- Commands:
  - help — show quick help
  - side white | side black — choose the human side
  - quit — exit the game

## Example

```
chezzig

+---+---+---+---+---+---+---+---+
| r | n | b | q | k | b | n | r | 8
+---+---+---+---+---+---+---+---+
| p | p | p | p | p | p | p | p | 7
+---+---+---+---+---+---+---+---+
|   |   |   |   |   |   |   |   | 6
+---+---+---+---+---+---+---+---+
|   |   |   |   |   |   |   |   | 5
+---+---+---+---+---+---+---+---+
|   |   |   |   |   |   |   |   | 4
+---+---+---+---+---+---+---+---+
|   |   |   |   |   |   |   |   | 3
+---+---+---+---+---+---+---+---+
| P | P | P | P | P | P | P | P | 2
+---+---+---+---+---+---+---+---+
| R | N | B | Q | K | B | N | R | 1
+---+---+---+---+---+---+---+---+
  a   b   c   d   e   f   g   h
White to move
> e2e4
AI plays e7e5
```

## Project Layout

- Build script: [build.zig](file:///Users/yahs/Documents/projects/chezzig/build.zig)
- Main program and engine: [src/main.zig](file:///Users/yahs/Documents/projects/chezzig/src/main.zig)
- GUI frontend (SDL2): [src/gui.zig](file:///Users/yahs/Documents/projects/chezzig/src/gui.zig)

## Optional: Use SDL.zig Instead of System Headers

You can link SDL2 via the SDL.zig package, avoiding system headers and gaining a more Zig‑friendly API.

Steps (summary):

- Add the dependency: `zig fetch https://github.com/ikskuh/SDL.zig` and record the printed hash in your `build.zig.zon` under a dependency named `sdl`.
- In your build script, initialize the SDK and link:
  - Initialize: `const sdk = sdl.init(b, .{});`
  - Link: `sdk.link(gui_exe, .dynamic, sdl.Library.SDL2)`
  - Expose API to your module: `root_module.addImport("sdl2", sdk.getNativeModule())`

This repository currently ships the GUI wired to system SDL2 by default. If you want, I can switch it over fully to SDL.zig on request.

## Implementation Notes

- State and board
  - 8×8 array of optional pieces with side‑to‑move, castling rights, en passant square, half/ full‑move counters
- Move generation
  - Pseudo‑legal moves per piece type followed by a legality filter that simulates the move and checks king safety
- Special rules
  - Castling requires clear path and non‑attacked path squares; rook is moved automatically
  - En passant captures the correct pawn even though the destination square is empty
  - Promotions accept an optional fifth character (e.g., e7e8q)
- AI
  - One‑ply material evaluation; deterministic and fast

## Building and Running

- Debug: `zig build`
- Run: `zig build run`
- Release: `zig build -Doptimize=ReleaseFast`
- GUI: `zig build run-gui`

## Roadmap

- Add threefold repetition and fifty‑move rule
- Add SAN/PGN I/O
- Improve AI with deeper search and alpha‑beta pruning
- Optional colored/Unicode board output

## Contributing

- Issues and pull requests are welcome. Please keep changes small and focused. If you plan larger features, consider opening an issue first for discussion.

## License

- No license has been specified yet. If you intend to distribute or reuse this code, add a LICENSE file to clarify terms.
