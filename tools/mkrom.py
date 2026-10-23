#!/usr/bin/env python3
"""Pad the 4 linked code banks to 128KB, append the Mode 7 tables, pad to 4MB, fix checksum."""
import sys

code, tables, out = sys.argv[1:4]
rom = bytearray(open(code, "rb").read())
assert len(rom) == 0x20000
rom += open(tables, "rb").read()
assert len(rom) <= 0x3F0000          # banks $7E/$7F are WRAM in LoROM
rom += b"\xff" * (0x400000 - len(rom))
rom[0x7FDC:0x7FE0] = b"\xff\xff\x00\x00"
s = sum(rom) & 0xFFFF
rom[0x7FDC:0x7FE0] = bytes([~s & 0xFF, (~s >> 8) & 0xFF, s & 0xFF, s >> 8])
open(out, "wb").write(rom)
