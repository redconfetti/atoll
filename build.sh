#!/bin/bash
# usage: ./build.sh [out.sfc] [extra ca65 flags, e.g. -D DEMO=1]
set -e
cd "$(dirname "$0")"
OUT=${1:-build/ww11.sfc}; shift || true
if [ ! -f build/gen.inc ] || [ tools/build_assets.py -nt build/gen.inc ]; then
  python3 tools/build_assets.py build
fi
ca65 --cpu 65816 -I build -I src --bin-include-dir build "$@" src/main.s -o build/main.o
ld65 -C src/lorom.cfg build/main.o -o build/code.bin
python3 tools/mkrom.py build/code.bin build/m7tables.bin "$OUT"
echo "built $OUT"
