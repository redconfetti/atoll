# Bikini Atoll

A Super Nintendo flight game, written in 65816 assembly. You fly a bomber across
the Pacific to Bikini Atoll, re-enacting the 1946 Operation Crossroads atomic
test on a fleet of uncrewed ships.

The ground is drawn in Mode 7, with a perspective matrix set for each scanline
by HDMA from precomputed ROM tables. The mushroom cloud is made with HDMA window
spans and colour math. Sound runs without an SPC700 program: the game writes
DSP registers directly through the APU's boot ROM loader.

## About this project

This game was generated with [Claude Code](https://claude.com/claude-code) as
a demo of its ability to make SNES games. The assembly source, the asset
generator, the build tools and this README were all written by Claude Code.

## Mission

1. Follow the red compass mark to the atoll.
2. Open the bomb bay.
3. Put the sight ring on the orange ship and drop when it reads OVER TARGET.
4. Break away: turn 155° before detonation.

The results screen shows how far from the target ship the bomb detonated and
how far you turned away.

## Controls

| SNES   | Keyboard (emulator) | Action             |
|--------|---------------------|--------------------|
| D-pad  | Arrows              | Bank / climb / dive |
| B      | X                   | Bomb bay doors     |
| A      | Z                   | Drop bomb          |
| X      | A                   | Change camera      |
| L / R  | Q / E               | Throttle           |
| START  | Enter               | Pause              |
| SELECT | ? or V              | Controls help      |

## Building

Requirements:

- [cc65](https://cc65.github.io/) (`ca65` and `ld65`)
- Python 3

```sh
./build.sh                    # writes build/ww11.sfc
./build.sh build/atoll.sfc    # choose the output file
```

`build.sh` regenerates the graphics and data tables with
`tools/build_assets.py` when that script has changed, assembles
`src/main.s`, links it into four LoROM code banks, and then runs
`tools/mkrom.py`. That script appends the Mode 7 tables, pads the ROM to 4 MB
and fixes the checksum.

Extra arguments are passed to `ca65`, which enables these test builds:

```sh
./build.sh build/demo.sfc -D DEMO=1                    # autopilot flies the whole bomb run
./build.sh build/up.sfc   -D DEMO=1 -D DEMO_HOLD=JOY_UP  # also hold a button throughout
./build.sh build/alt.sfc  -D DEMO=1 -D DEMO_ALT=1        # alternate climbing and descending
```

## Running

Load the `.sfc` file in any SNES emulator, such as Mednafen, bsnes or Mesen.

`tools/shot.sh` takes screenshots without a display, using Xvfb, Mednafen and
ImageMagick:

```sh
tools/shot.sh build/demo.sfc build/s 2 10 20   # screenshots at 2, 10 and 20 s
```

## Layout

| Path                    | Contents                                         |
|-------------------------|--------------------------------------------------|
| `src/main.s`            | The game: main loop, flight, HUD, sprites, explosion, sound |
| `src/snes.inc`          | SNES hardware register definitions               |
| `src/lorom.cfg`         | ld65 memory map (LoROM, 4 code banks)            |
| `tools/build_assets.py` | Generates the map, tiles, palettes, text screens and Mode 7 tables |
| `tools/mkrom.py`        | Builds the final 4 MB ROM image                  |
| `tools/shot.sh`         | Headless screenshot capture                      |
| `build/`                | Generated assets, ROMs and test screenshots      |
