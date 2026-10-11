# Contributing to the Shufflepuck Cafe recomp

This repository is the game-specific half: the build script, the loader
(`src/main.c`), the setup script, the conformance harness and the reverse-
engineering notes. The recompiler and the Toolbox HAL are
[macrecomp](https://github.com/sp00nznet/macrecomp), vendored as a submodule at
`ext/macrecomp`. Contributions to either are welcome.

## Where the gaps are

| Area | What is missing | Difficulty |
|---|---|---|
| **Reaching the event loop** | The game parks in its intro/init loop. Find what it waits on. | Medium |
| **ASND sound** | Broderbund's custom async-sound container: reverse it, play it through SDL. | Medium |
| **Jump-table second pass** | ~35 tail entries come from the loader's 0x138 LFSR pass, not yet replicated in `unprotect.py`. | Small |

## Ground rules

**No game files, ever.** No disk images, resource forks, `CODE`/`PICT`/`ASND`
dumps, or decrypted segments. No lifted code either: `work/` and `src/gen/` are
generated from your own copy and gitignored, and must stay that way. No
disassembly listings in docs: describe what the code does in prose. Screenshots
of what the recompiled game renders are fine.

**Where your code comes from.** Contributions must be your own work or under
an MIT-compatible licence. The easy mistake is porting a fix you saw in a GPL
project (Mini vMac, Basilisk II, SheepShaver, QEMU, MAME's GPL parts), which
relicenses it by accident and is very hard to untangle later. Running an
emulator as a black box and comparing output is fine; reading its source and
writing "our own" version is not. If you port anything, say where it came from
in the pull request.

**Generic fixes go upstream.** If the bug is in the lifter, the unprotector or
the Toolbox HAL, it belongs in macrecomp as its own PR, and this repo only
picks it up by bumping the submodule. Shufflepuck-specific values stay here.

**Say what you measured.** Show the conformance run before and after
(`py -3 tools/conformance.py`), and the log line or frame that changed.

**AI-assisted contributions** are welcome, provided a human understood and
verified the change.

## Before you open a pull request

With your own copy set up (README, Getting Started):

```
./build.sh
py -3 tools/conformance.py
```
