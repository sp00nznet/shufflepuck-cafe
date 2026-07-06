# Phase 0 — Reconnaissance

## Provenance

| | |
|---|---|
| Title | *Shufflepuck Cafe* v1.0 |
| Publisher | Broderbund Software, 1988 |
| Authors | Christopher Gross, Lauren Elliott, Gene Portwood |
| Platform | Macintosh 68k, System 6/7, 512×342 1-bit B&W |
| Source image | Internet Archive `ShufflepuckCafe4amMacCrack` → `00playable2.dc42` |
| Format | DiskCopy 4.2, 800 KB (84-byte header + 819200 HFS + 19200 tags) |
| Provenance note | 4am de-protected crack. The copy-protection check is nopped — a *plus* for recomp (one less trap path to satisfy). Logic is otherwise the stock v1.0. A pristine flux original (`.moof`) exists in the `moofaday_Shufflepuck_Cafe` item if byte-exact code ever matters. |

The image is a 2-disk set: `00playable.dc42` is the boot **System** disk;
`00playable2.dc42` holds the game. **Nothing from either disk is committed** —
`original/` and `work/` are gitignored (commercial abandonware).

## The application

```
/Shufflepuck Cafe   type=APPL  creator=PUCK   data fork=24,310 B   rsrc fork=644,810 B
```

The data fork (24,310 B) on an APPL is unusual — likely packed game data
(tables/state); to be identified in Phase 1.

## Resource map (23 types)

Extracted with `ext/macrecomp/tools/extract_resources.py` → `work/inventory.json`.

| Type | Count | Bytes | What it is |
|------|------:|------:|------------|
| `ASND` | 27 | 391,575 | **Custom** Broderbund async-sound. Paddle cracks, taunts, ambience. Format TBD. |
| `PICT` | 187 | 177,354 | Standard 1-bit QuickDraw pictures: table, bar, every opponent's frames. |
| `CODE` | 6 | 54,202 | The 68k program (see below). |
| `FONT` | 5 | 12,600 | Bitmap fonts. |
| `DITL` | 9 | 800 | Dialog item lists. |
| `STRS` | 1 | 640 | **Custom** string blob (note: not standard `STR#`). |
| `MENU` | 7 | 535 | Menus. |
| `ICON` | 3 | 384 | Icons. |
| `ICN#` | 1 | 256 | Finder icon. |
| `DATA` | 1 | 200 | **Custom** data blob. |
| `FOND` | 2 | 126 | Font family descriptors. |
| `PAT ` | 14 | 112 | QuickDraw fill patterns. |
| `CREL` | 2 | 96 | **Custom** — likely CODE relocation table. |
| `ALRT` | 7 | 84 | Alerts. |
| `CURS` | 1 | 68 | Cursor. |
| `DLOG` | 2 | 59 | Dialogs. |
| `WIND` | 2 | 52 | Windows (the game window + one more). |
| `PUCK` | 1 | 34 | **Custom** signature/config (matches creator). |
| `ZERO` | 1 | 30 | **Custom** — purpose TBD. |
| `BNDL` | 1 | 28 | Finder bundle. |
| `SIZE` | 1 | 10 | Size/SysHeap hints. |
| `FREF` | 1 | 7 | File reference. |
| `DREL` | 1 | 0 | **Custom** — likely DATA relocation table (empty here). |

## CODE segments (the lift target)

| Segment | Bytes | Role (hypothesis) |
|--------:|------:|-------------------|
| CODE 0 | 2,136 | A5 **jump table** (segment loader dispatch), not executable code. |
| CODE 1 | 996 | Small — startup / `%_MStart`-style glue. |
| CODE 2 | 23,006 | Large — core game logic. |
| CODE 3 | 32 | Tiny — a single routine (a trampoline?). |
| CODE 4 | 1,322 | Small. |
| CODE 5 | 26,710 | Large — logic / physics / opponent AI. |

**~52 KB of real 68k across 5 segments** (CODE 0 excluded). Smaller than Bolo.

## Scope read (informs Phase 2)

Single B&W window, mouse-driven. The Toolbox surface should be bounded:

- **QuickDraw** — `CopyBits`/`DrawPicture` blitting the 187 PICTs; `PaintRect`,
  patterns, the puck/paddle motion. The primary HAL.
- **Event Manager** — `GetNextEvent`/`Button`/mouse tracking; the main loop.
- **Menu / Window / Dialog** — small (7 MENU, 2 WIND, a few DLOG/ALRT).
- **Sound** — 27 `ASND` played through a custom driver (may bypass Sound Mgr and
  hit the Sound Driver directly — to be seen when we scan traps).

**Open questions for Phase 1–2**
1. What are the data fork + `DATA`/`STRS`/`ZERO` blobs? (opponent tables? scores?)
2. `ASND` internal format — raw 8-bit @ 22 kHz? Mac `snd `-like? headered?
3. Do `CREL`/`DREL` mean the game does its own relocation on top of the loader?
4. The exact A-trap set (Phase 2) — the real measure of Phase-4 cost.
