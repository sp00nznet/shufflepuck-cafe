#!/usr/bin/env bash
# Build Shufflepuck Cafe from YOUR OWN disk image.
#
# Regenerates the lifted code (nothing game-derived is committed to this repo)
# then compiles. Needs: python3 + macresources/machfs/capstone, and a C compiler.
#   ./build.sh ["path/to/Shufflepuck Cafe - Disk 2 (Game).dc42"]
#
# On Windows/MSYS2 put the mingw toolchain on PATH first:
#   export PATH="/c/msys64/mingw64/bin:$PATH"
set -euo pipefail

IMG="${1:-original/Shufflepuck Cafe - Disk 2 (Game).dc42}"
MR=ext/macrecomp
CC="${CC:-gcc}"

[ -f "$IMG" ] || { echo "disk image not found: $IMG"; echo "bring your own copy (see README)"; exit 1; }

echo ">> extract resources"
python "$MR/tools/extract_resources.py" "$IMG" -o work
echo ">> unprotect (defeat HLS Duplication)"
python "$MR/tools/unprotect.py" work/code -o work/unpacked
echo ">> lift 68k -> C"
python "$MR/tools/lift68k.py" work/unpacked/CODE_1.dec.bin --seg 1 --jt work/unpacked/jumptable.json -o src/gen
python "$MR/tools/lift68k.py" work/unpacked/CODE_5.dec.bin --seg 5 --jt work/unpacked/jumptable.json -o src/gen
# seg 2 needs the boot entry (0x3838) forced as a function (nothing bsr's to it)
python "$MR/tools/lift68k.py" work/unpacked/CODE_2.dec.bin --seg 2 --jt work/unpacked/jumptable.json --entry 0x3838 -o src/gen

echo ">> compile + link (SDL2 Toolbox HAL)"
mkdir -p build
$CC -std=c11 -O1 -I"$MR/include" $(pkg-config --cflags sdl2) \
    src/main.c src/gen/code_1.c src/gen/code_2.c src/gen/code_5.c \
    "$MR/runtime/m68k.c" "$MR/runtime/quickdraw.c" "$MR/runtime/toolbox.c" "$MR/runtime/platform_sdl.c" \
    -DMACRECOMP_NO_TRAP_STUB $(pkg-config --libs sdl2) -lm -o build/shufflepuck
echo ">> built build/shufflepuck  (run: ./build/shufflepuck work/unpacked)"
