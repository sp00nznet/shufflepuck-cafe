#!/usr/bin/env bash
# Build Shufflepuck Cafe from YOUR OWN disk image.
#
# Regenerates the lifted code (nothing game-derived is committed to this repo)
# then compiles. Needs: python3 + macresources/machfs/capstone, and a C compiler.
#   ./build.sh ["path/to/Shufflepuck Cafe - Disk 2 (Game).dc42"]
# PYTHON, CC and PKG_CONFIG override the tools (Setup.cmd passes PYTHON).
#
# On Windows/MSYS2 put the mingw toolchain on PATH first:
#   export PATH="/c/msys64/mingw64/bin:$PATH"
set -euo pipefail

IMG="${1:-original/Shufflepuck Cafe - Disk 2 (Game).dc42}"
MR=ext/macrecomp
CC="${CC:-gcc}"
PY="${PYTHON:-python}"
PKG="${PKG_CONFIG:-pkg-config}"

# No image but a lift already in src/gen (a netlab builder, which gets the
# generated C but never game data): compile only.
if [ ! -f "$IMG" ] && ls src/gen/code_*.c >/dev/null 2>&1; then
  echo ">> no disk image; compiling the existing src/gen"
else
[ -f "$IMG" ] || { echo "disk image not found: $IMG"; echo "bring your own copy (see README)"; exit 1; }

echo ">> extract resources"
$PY "$MR/tools/extract_resources.py" "$IMG" -o work
echo ">> unprotect (defeat HLS Duplication)"
$PY "$MR/tools/unprotect.py" work/code -o work/unpacked
echo ">> lift 68k -> C"
for s in 1 3 5; do
  $PY "$MR/tools/lift68k.py" "work/unpacked/CODE_${s}.dec.bin" --seg "$s" --jt work/unpacked/jumptable.json -o src/gen
done
# seg 2: force the boot main (0x3a06) as a function (only the embedded _MStart calls it)
$PY "$MR/tools/lift68k.py" work/unpacked/CODE_2.dec.bin --seg 2 --jt work/unpacked/jumptable.json --entry 0x3a06 -o src/gen

echo ">> decode PICT art (for CopyBits/DrawPicture)"
$PY "$MR/tools/pict2png.py" work/rsrc -o work/pict_png || true
fi

echo ">> compile + link (SDL2 Toolbox HAL)"
mkdir -p build
$CC -std=c11 -O1 -I"$MR/include" $($PKG --cflags sdl2) \
    src/main.c src/gen/code_*.c \
    "$MR/runtime/m68k.c" "$MR/runtime/quickdraw.c" "$MR/runtime/toolbox.c" "$MR/runtime/platform_sdl.c" \
    "$MR/runtime/dialog.c" "$MR/runtime/files.c" "$MR/runtime/textedit.c" \
    -DMACRECOMP_NO_TRAP_STUB $($PKG --libs sdl2) -lm -o build/shufflepuck
echo ">> built build/shufflepuck  (run: ./build/shufflepuck work/unpacked)"
