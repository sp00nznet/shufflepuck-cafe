# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/). Nothing is tagged yet.

## [Unreleased]

### Added
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
