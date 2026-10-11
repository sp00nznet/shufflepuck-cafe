# Architecture

Two languages, two repos, one pipeline. Python tools (in macrecomp) turn your
disk image into C; a C compiler links that C against macrecomp's Toolbox HAL
and this repo's loader.

```
original/*.dc42 ──extract_resources.py──▶ work/code/CODE_*.bin + work/rsrc/*.bin
                                            │
                     unprotect.py ◀─────────┘
                          │
                          ▼
            work/unpacked/CODE_*.dec.bin + jumptable.json
                          │
                     lift68k.py (per segment)
                          ▼
                    src/gen/code_*.c ──┐
                                       ├──gcc──▶ build/shufflepuck(.exe)
  src/main.c + ext/macrecomp/runtime ──┘
                                              │ at run time reads
                                              ▼
                              work/unpacked/ (segments) + work/rsrc/ (PICT, MENU…)
```

## Who owns what

| Part | Where | Owns |
|---|---|---|
| Resource extractor | `ext/macrecomp/tools/extract_resources.py` | Mounting the HFS image and splitting the resource fork into one file per resource. |
| Unprotector | `ext/macrecomp/tools/unprotect.py` | Defeating HLS Duplication: decrypting CODE 0's jump table and every segment body. See [PROTECTION.md](PROTECTION.md). |
| Lifter | `ext/macrecomp/tools/lift68k.py` | 68k → C, one C function per 68k routine, A-traps lowered to HAL calls. |
| Toolbox HAL | `ext/macrecomp/runtime/` | CPU state (`m68k.c`), QuickDraw, the Toolbox managers, and the SDL2 platform layer. |
| Loader | `src/main.c` | Shufflepuck's memory map: where each segment and the A5 world sit, wiring the jump table to lifted functions, registering resources, calling the game's main. |
| Build | `build.sh` | Running the steps above in order. `tools/setup.ps1` (via `Setup.cmd`) runs the same steps. |

## Why the split is where it is

- **The loader is game-specific, the HAL is not.** Segment bases, the main
  entry (`fn_2_3a06`), and the decision to skip CODE 4 (the protection loader,
  replaced by the static unprotect step) are Shufflepuck facts. Everything a
  second Mac title would need lives in macrecomp.
- **Segments are lifted *and* loaded raw.** The lifted C runs the code, but the
  game also reads its own segments as data (jump-table thunks, embedded
  tables), so `main.c` copies the decrypted bytes into the flat 32 MB address
  space at the same bases the lifter was told.
- **Seg 2 is lifted with `--entry 0x3a06`** because the real main is only
  reachable from the embedded `_MStart` glue, which the lifter's call graph
  doesn't see.
- **Nothing generated is committed.** `work/` and `src/gen/` derive from the
  copyrighted binary, so every build regenerates them from the user's image.
