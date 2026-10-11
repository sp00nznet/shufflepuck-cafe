# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/). Nothing is tagged yet.

## [Unreleased]

### Added
- **A whole match**: play to 15 and go back to the bar with Ctrl+O (Game >
  New Opponent). The champion board shows its name in the game's own font.
  Needs macrecomp #6 (fonts, a relative `Move`) and #7 (Command-key menus,
  `HiWord`/`LoWord`), and #5's follow-up (the input script stopped at 1024
  steps). Walls 7-9 in `docs/bringup.md`.
- `--stroke x0,y0:x1,y1@s+dur` (a mouse glide in one argument), `--key ^c@s`
  (with Command), and the score in the `[game]` line.
- Conformance: 10/10, adding "the opponent scores" (a5-0xca6).
- **A playable match**: title, bar, pick an opponent, the table, serve and
  volley. Needs macrecomp #2-#5 (banded DrawPicture into offscreen ports, the
  event mask and FlushEvents, pen patterns and CopyBits modes, scripted input).
  Walls and evidence in `docs/bringup.md`.
- The loader runs THINK C's startup (CODE 1 `0x340` and `0xb8`) before main,
  so the initialised globals from `DATA 0`/`ZERO 0` and the `STRS 0` pool are
  in place. Without them the paddle's half-width was 0.
- `--move x,y@s`, `--click x,y@s`, `--key c@s` (scripted input), and a
  `[game]` state line at exit for the harness.
- Conformance: 9/9 milestones, through a scripted pick of Skip and three
  serves (was 6/6, boot only).
- The game reaches its event loop and plays the intro: credits, then the
  cantina. It needed its own data fork registered with the File Manager;
  without it the open failed and the game raised "Sorry, this disk is full."
- `--headless`, `--record out.mp4` and `--watchdog secs` (needs macrecomp#1).
- `tools/conformance.py` and its baseline `conformance.json`: 6/6 boot
  milestones, 7 untranslated instructions; fails on regression.
- `Setup.cmd` (one-click setup, `tools/setup.ps1`), a netlab recipe
  (`netlab check shufflepuck`; netlab#8) and its QA wrapper `tools/qa.cmd`.
- CI: lint the pipeline and run the harness, which skips without game data.
- `CHANGELOG.md`, `ROADMAP.md` (moved from `docs/PLAN.md`), `CONTRIBUTING.md`,
  `docs/architecture.md`.
- Offscreen QuickDraw renders real 1-bit content; the game runs its render loop
  (700k+ traps) and parks in its intro/init loop before the event loop.
- The lifted game boots through the Toolbox HAL and draws its 1988 title screen.
- Phase 3: every 68k segment lifted to C (98.5 / 99.9 / 100% coverage); the
  whole program compiles and links.
- Phase 2.5: the HLS Duplication copy protection defeated statically and
  byte-exact (`ext/macrecomp/tools/unprotect.py`), documented in
  `docs/PROTECTION.md`.
- Phase 2: trap-surface classification (`docs/CLASSIFY.md`).
- Phase 0: recon of the v1.0 disk (`docs/RECON.md`) and the repo scaffold.

### Changed
- Relifted on current macrecomp (108 commits newer). CODE 1 went from 98.5% to
  99.0% covered, and CODE 2's untranslated instructions went from 6 to 4. The
  pinned lifter could no longer lift CODE 1 at all. The build links three more
  runtime files (dialog, files, textedit).
- `build.sh` honours `PYTHON` and `PKG_CONFIG`, and with no disk image compiles
  an existing `src/gen` (how netlab builds it).
- `docs/CLASSIFY.md` describes the protection loader in prose, not as a
  disassembly excerpt.
- `LICENSE` is the plain MIT text; the note that it does not cover the game
  itself moved to the README.

### Fixed
- The black screen in Phase 5 was the lifter lowering 68k `jmp` as a call,
  which corrupted THINK C's Memory Manager glue stack (fixed in macrecomp
  `63e1d82`).
