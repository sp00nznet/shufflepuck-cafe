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
for s in 1 2 5; do
  python "$MR/tools/lift68k.py" "work/unpacked/CODE_${s}.dec.bin" --seg "$s" \
      --jt work/unpacked/jumptable.json -o src/gen
done
echo ">> compile + link"
mkdir -p build
$CC -std=c11 -O1 -I"$MR/include" \
    src/main.c src/gen/code_1.c src/gen/code_2.c src/gen/code_5.c \
    "$MR/runtime/m68k.c" -o build/shufflepuck
echo ">> built build/shufflepuck"
./build/shufflepuck || true
