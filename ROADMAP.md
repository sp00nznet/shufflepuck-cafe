# Roadmap

Static recompilation of *Shufflepuck Cafe* (Mac 68k) via the
[macrecomp](https://github.com/sp00nznet/macrecomp) toolkit. Same shape as the
DOS-era Bolo/SkiFree recomps, retargeted from 8086+DOS to 68k+Toolbox.

## Done

- **Phase 0 — Acquire + recon.** 6 CODE segments (~52 KB of 68k), 187 PICT,
  27 ASND. See [docs/RECON.md](docs/RECON.md).
- **Phase 1 — Extract resources** with macrecomp's `extract_resources.py`.
- **Phase 2 — Disassemble + classify (the go/no-go gate).** GO: 182 distinct
  traps, ordinary QuickDraw + events + menus. See [docs/CLASSIFY.md](docs/CLASSIFY.md).
- **Phase 2.5 — Defeat the HLS Duplication protection** statically and
  byte-exact. See [docs/PROTECTION.md](docs/PROTECTION.md).
- **Phase 3 — Lift 68k → C.** Whole program compiles and links.
- **Phase 4 — Toolbox HAL → SDL2**, in `ext/macrecomp/runtime`.
- **Headless mode** (`--headless --record out.mp4 --watchdog N`) and the
  conformance harness (`tools/conformance.py`).

## Next

- **Phase 5 — Debug to playable.** The game reaches its event loop and plays
  the intro (credits, then the cantina). Next: input, the menu, and a playable
  table against one opponent.
- **The 7 untranslated instructions:** three computed `jmp (a0,dN.w)` in
  CODE 1, the `sr` save/restore and one `asl.w` memory form in CODE 2.
- **ASND sound.** Broderbund's custom async-sound container, reversed and
  played through SDL audio.
- **Jump-table second pass.** ~35 tail entries are finished by the loader's
  0x138 LFSR pass, not yet replicated.

## Deferred

- **Phase 6 — Extras:** widescreen, save states, difficulty tuning, a practice
  mode against the unbeatable opponents. After the game is playable.

## Out of scope

- Shipping game data, lifted code or decrypted segments in any form. You bring
  your own copy; the build regenerates everything locally.
- Other Broderbund titles. Reusable work goes into macrecomp, not here.

## Guiding principles

- **Gate before grind.** Phases 0–2 were cheap and decided everything.
- **Toolkit vs game.** Anything reusable (extract/disasm/lift, the Toolbox HAL)
  lives in `macrecomp`. Only Shufflepuck-specific glue lives here.
- **Public-clean from commit #1.** No copyrighted game bytes in the repo, ever.
