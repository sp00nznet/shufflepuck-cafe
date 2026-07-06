# Roadmap

Static recompilation of *Shufflepuck Cafe* (Mac 68k) via the
[macrecomp](https://github.com/sp00nznet/macrecomp) toolkit. Same shape as the
DOS-era Bolo/SkiFree recomps, retargeted from 8086+DOS to 68k+Toolbox.

## Phases

**Phase 0 — Acquire + recon** ✅
Get a mountable HFS image, extract every resource, catalogue it. Done — see
[RECON.md](RECON.md). Result: 6 CODE segments (~52 KB of 68k), 187 PICT, 27 ASND.

**Phase 1 — Extract & identify assets**
- CODE segments → `work/code/CODE_*.bin` (done by the extractor).
- Decode the 187 `PICT`s (1-bit QuickDraw) to PNG for eyeballing.
- Reverse the `ASND` container; dump to WAV.
- Identify the data fork + `DATA`/`STRS`/`ZERO` blobs.

**Phase 2 — Disassemble + classify** ⭐ **GO / NO-GO GATE**
- capstone-M68K disassembly of CODE 1–5; rebuild CODE 0's jump table and the A5
  world so inter-segment calls resolve.
- Recover function boundaries + call graph.
- **Enumerate every A-line (`$Axxx`) Toolbox trap the game calls.** This set *is*
  the Phase-4 workload. A small, familiar set (QuickDraw + Event + Sound) = GO.
  A sprawling one = reconsider scope.
- Deliverable: `docs/CLASSIFY.md` with the trap list and per-segment map.

**Phase 3 — Lift 68k → C**
Mechanical lifter (macrecomp `lift68k.py`): model D0–D7/A0–A7, CCR, and the 68k
addressing modes; one C function per subroutine; A-traps become calls into the
macrecomp runtime. Output → `src/gen/`.

**Phase 4 — Toolbox HAL → SDL2**
Implement *only* the traps Phase 2 found, in `ext/macrecomp/runtime`:
QuickDraw `CopyBits`/PICT blit (1-bit → RGBA framebuffer), Event Mgr → SDL
events, Menu/Window/Dialog chrome, Sound (ASND → SDL audio). Reusable across
future Mac recomps.

**Phase 5 — Build & debug to playable**
Compile lifted code + HAL, boot into the cantina, drive to a playable table
against at least one opponent. Iterate until it's fun again.

**Phase 6 — Ship native + extras**
Widescreen, save states, restored/edited sound, difficulty tuning, maybe a
practice mode against the unbeatable ones.

## Guiding principles

- **Gate before grind.** Phases 0–2 are cheap and decide everything; don't lift a
  line of C until the trap set says the HAL is tractable.
- **Toolkit vs game.** Anything reusable (extract/disasm/lift, the Toolbox HAL)
  lives in `macrecomp`. Only Shufflepuck-specific glue lives here.
- **Public-clean from commit #1.** No copyrighted game bytes in the repo, ever.
