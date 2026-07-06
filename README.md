<div align="center">

# 🏓 SHUFFLEPUCK CAFE — a static recomp

```
   ___ _  _ _   _ ___ ___ _    ___ ___ _   _ ___ _  _
  / __| || | | | | __| __| |  | __| _ \ | | / __| |/ /
  \__ \ __ | |_| | _|| _|| |__| _||  _/ |_| | (__| ' <
  |___/_||_|\___/|_| |_| |____|___|_|  \___/ \___|_|\_\
              C   A   F   E   ·   1 9 8 8
```

**Broderbund, 1988 → native code, today.**
No emulator. The original 68k Macintosh binary, taken apart and rebuilt.

</div>

---

## What is this?

*Shufflepuck Cafe* is a 1988 air-hockey game by **Broderbund** (Christopher Gross,
Lauren Elliott, Gene Portwood). You bellied up to a table in a grimy spaceport
cantina and played one-on-one puck against a gallery of weirdos — the twitchy
robot **Skip Feeney**, the cheating alien **Biff Raunch**, the untouchable
**Princess Bejin**, the monstrous **Adder** — in glorious 512×342 **1-bit black &
white**. The paddle tracked your mouse, the puck cracked off the walls, and your
opponents *talked trash*. A certain kind of kid (👋) sank whole weekends into it.

It's also wonderfully *small* — one `PUCK`-creator application, **6 CODE segments,
~52 KB of 68k**, and its art/sound as resources — which makes it a great candidate
for **static recompilation**: not emulating a Mac, but lifting the original 68000
machine code into C that compiles and runs natively today.

This repo is that effort, built with the [**macrecomp** toolkit](https://github.com/sp00nznet/macrecomp)
(vendored at [`ext/macrecomp`](ext/macrecomp)) — the classic-Mac sibling of the
DOS-era pcrecomp pipeline that resurrected *Bolo* and *SkiFree*.

## Why bother?

Because emulation runs old games; recompilation *frees* them. The output is native
code you can read, debug, fix and extend — widescreen, save states, restored
sound, maybe even the opponents nobody could beat. And because some games deserve
to outlive their 800K floppies.

## How it works

```
  Shufflepuck Cafe (HFS app: CODE 0..5 + 187 PICT + 27 ASND + MENU/DITL/…)
        │  ① extract      ext/macrecomp/tools/extract_resources.py
        ▼
  CODE segments + asset catalog
        │  ② disassemble   capstone M68K
        │  ③ classify      enumerate Toolbox A-traps   ← the go/no-go gate
        ▼
  function table + trap set
        │  ④ lift          68k → C against the macrecomp runtime
        ▼
  C source  ──⑤ HAL──▶  QuickDraw→SDL2, Toolbox→runtime  ──⑥ build──▶  native PUCK
```

## Status

🚧 **Phase 0 done — the patient is on the table and it's a clean, small one.**

Real recon from the 4am-cracked v1.0 disk (`Shufflepuck Cafe`, type `APPL`,
creator `PUCK`, 644 KB resource fork):

- ✅ **Acquired & mounted** the HFS image; extracted every resource with
  macrecomp's `extract_resources.py`. Full map in [`docs/RECON.md`](docs/RECON.md).
- ✅ **Code is tiny:** `CODE` 0–5 = **54,202 bytes** (seg 0 is the 2,136-byte A5
  jump table; the real logic is ~52 KB across 5 segments — smaller than Bolo).
- ✅ **Assets catalogued:** **187 `PICT`** (177 KB, standard 1-bit QuickDraw — the
  table, the bar, every opponent's animation frames), **27 `ASND`** (391 KB —
  Broderbund's *custom* async-sound type, to be reversed), bitmap `FONT`/`FOND`,
  and normal `MENU`/`DITL`/`DLOG`/`WIND`/`ALRT`/`CURS`.
- 🔎 **Scope read:** single B&W window + mouse. The Toolbox surface should be
  bounded — QuickDraw blit, the event loop, a few menus/dialogs, and sound.
  Phase 2 counts the exact traps and confirms.

| Phase | What | State |
|------:|------|-------|
| 0 | Acquire + recon | ✅ [`docs/RECON.md`](docs/RECON.md) |
| 1 | Extract resources (CODE + assets) | ✅ via `ext/macrecomp` |
| 2 | Disassemble + classify trap surface | ✅ [`docs/CLASSIFY.md`](docs/CLASSIFY.md) — **GO, but the code is protected** |
| 2.5 | Unpack the self-decrypting CODE | 🔨 **next** |
| 3 | Lift 68k → C | ⬜ |
| 4 | Toolbox HAL → SDL2 (QuickDraw/Event/Sound) | ⬜ |
| 5 | Build & debug to a playable table | ⬜ |
| 6 | Ship native + extras | ⬜ |

> **Phase 2 plot twist:** the game is copy-protected. The 68k code is *encrypted
> at rest* inside the `CODE` resources; **CODE 4 is a plaintext self-decrypting
> segment loader** (entry point at seg 4 +0x42) that unpacks the rest at launch.
> Proven by a control (the disk's Finder disassembles cleanly; Shufflepuck's CODE
> is noise) and by reading CODE 4's `neg.w`-loop / `_NewPtr` / `_GetResource`
> decryptor. It's not a simple cipher (tested). So a small **Phase 2.5 unpack**
> lands before lifting — either a dynamic snapshot (let it decrypt itself, dump
> memory — how Bolo beat PKLITE) or a static reversal of CODE 4. See
> [`docs/CLASSIFY.md`](docs/CLASSIFY.md).

See [`docs/PLAN.md`](docs/PLAN.md) for the roadmap.

## Repo layout

```
shufflepuck-cafe/
  ext/macrecomp/   the 68k-Mac static-recomp toolkit (git submodule)
  docs/            RECON.md · PLAN.md
  original/        your own copy of the game (gitignored — see below)
  work/            regeneratable extraction/analysis output (gitignored)
  src/             lifted + hand-written runtime glue (later phases)
```

## Building & running

Nothing to build yet — we're at Phase 0/2. Clone with the toolkit submodule:

```bash
git clone --recursive https://github.com/sp00nznet/shufflepuck-cafe.git
# already cloned?
git submodule update --init --recursive
```

Bring your own disk image (see legal note), then extract to start digging:

```bash
python ext/macrecomp/tools/extract_resources.py "original/Shufflepuck Cafe.dc42" -o work/
```

## Credits & legal

Original game © 1988 **Broderbund Software** (Christopher Gross, Lauren Elliott,
Gene Portwood). *Shufflepuck Cafe* is long out of print and unsupported. This is
a personal preservation / reverse-engineering project.

**No game code or data is included in this repository.** Unlike freely-licensed
shareware, Shufflepuck is commercial abandonware — so the disk image, the
extracted `CODE`/`PICT`/`ASND` resources, and any lifted representation of them
stay out of the repo (`original/` and `work/` are gitignored). You supply your
own copy; a v1.0 image is preserved by the community on the Internet Archive and
Macintosh Garden. All original code here (tooling and hand-written runtime) is
MIT-licensed — see [LICENSE](LICENSE).

Built with [macrecomp](https://github.com/sp00nznet/macrecomp) and far too much
nostalgia for a cantina that never existed.
