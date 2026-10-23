#!/bin/bash
# usage: shot.sh rom.sfc out_prefix t1 [t2 ...]  -- screenshots at given seconds after boot
ROM=$1; OUT=$2; shift 2
DISP=:77
Xvfb $DISP -screen 0 800x600x24 >/dev/null 2>&1 &
XP=$!
sleep 1
DISPLAY=$DISP mednafen -sound 0 -video.fs 0 -snes.xscale 2 -snes.yscale 2 -snes.stretch 0 "$ROM" > "$OUT.log" 2>&1 &
MP=$!
START=$(date +%s.%N)
for T in "$@"; do
  NOW=$(date +%s.%N)
  W=$(python3 -c "print(max(0, $START + $T - $NOW))")
  sleep "$W"
  import -display $DISP -window root "${OUT}_${T}.png"
done
kill $MP 2>/dev/null; sleep 0.3; kill $XP 2>/dev/null
