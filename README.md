# Chezzig - Zig Chess Game

![Zig Version](https://img.shields.io/badge/Zig-0.15.x-orange?logo=zig&style=for-the-badge) ![Build](https://img.shields.io/badge/build-zig%20build-informational?style=for-the-badge) ![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey?style=for-the-badge)

Modern, minimal command‑line chess written in Zig. It includes full legal move generation, check detection, castling, en passant, promotion, and a simple material‑based AI.

## Features

- Full move rules: pawns (double push, captures, en passant), knights, bishops, rooks, queen, king
- Castling with square safety checks and rook movement
- Promotion to queen/rook/bishop/knight
- Legality filter: rejects moves that leave your king in check
- Checkmate and stalemate detection
- Simple AI that selects the move with the best material outcome
- Clean terminal board rendering and compact input format

## Quick Start

1. Prerequisites

- Zig 0.15.x

2. Build

```bash
zig build
```

3. Run

```bash
zig build run
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
8 r n b q k b n r
7 p p p p p p p p
6 : . : . : . : .
5 . : . : . : . :
4 : . : . : . : .
3 . : . : . : . :
2 P P P P P P P P
1 R N B Q K B N R
  a b c d e f g h
White to move
> e2e4
AI plays e7e5
```

## Project Layout

- Build script: [build.zig](file:///Users/yahs/Documents/projects/chezzig/build.zig)
- Main program and engine: [src/main.zig](file:///Users/yahs/Documents/projects/chezzig/src/main.zig)

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

## Roadmap

- Add threefold repetition and fifty‑move rule
- Add SAN/PGN I/O
- Improve AI with deeper search and alpha‑beta pruning
- Optional colored/Unicode board output

## Contributing

- Issues and pull requests are welcome. Please keep changes small and focused. If you plan larger features, consider opening an issue first for discussion.

## License

- No license has been specified yet. If you intend to distribute or reuse this code, add a LICENSE file to clarify terms.
