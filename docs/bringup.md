# Bring-up: from the intro to a live match

Each wall between "reaches the event loop" and "serves and volleys", in the
order they were hit, with the evidence that found it. The fixes for the first
four are toolkit PRs (macrecomp #2-#5); the last is this repo's loader
(`src/main.c`). The tools that found them are worth knowing first.

## Tools

| Knob | What it shows |
|---|---|
| `--headless --record out.mp4 --watchdog N` | The whole run as video, no window. Contact sheet: `ffmpeg -i out.mp4 -vf "fps=1/3,scale=256:-1,tile=4x3" -frames:v 1 tiles.png` |
| `MRGFX=1` | Every GetPicture, DrawPicture (frame, dst, target bitmap) and CopyBits (rects, mode, bounds) |
| `MRBMSHOT=<hexbase>:<rowbytes>:<height>:f.pgm` | An offscreen bitmap from guest memory. Tells "never drawn" from "drawn, then lost" |
| `MRTRACE=1` | Every trap with the function it came from; pipe through `grep -v '\$A975'` (TickCount is 2M+ calls) |
| `MRTRAPS=1` | Trap histogram at exit |
| `MRWATCHADDR=<hex>` | Every write to one address, with the writer. A5 is `0x200000`, so a5-0x696 is `1ff96a` |
| `MRFILE=1` | File Manager calls: which data-fork bytes land where |

## 1. The cantina was sprites on black

The bar drew its patrons' faces over a black void. `MRBMSHOT` of both
offscreen buffers (`805680` background, `80ac00` composite) showed both black.
`MRGFX` showed `DrawPicture frame=0,0,342,512 into 805680`: the picture was
being drawn, into the right buffer. The PICTs are 22 PackBitsRect bands of 16
rows each (`pict2png` writes them as `PICT_1007_0..21.png`), and the runtime's
DrawPicture returned after the first band, wrote to the screen regardless of
the port, and stretched that band over the whole destination. **Fix: macrecomp
#2.**

## 2. A click on an opponent did nothing

`MRTRACE` around the injected click: the mouseDown went to a GetNextEvent from
`fn_2_2eca`, not the bar loop at `fn_5_634a`. The bar asks with mask 2
(mouseDown); `fn_2_2eca` is the keyboard handler and asks with `0x48`
(keyDown|updateEvt). The runtime popped the mask and ignored it, so whichever
poll came first took the click and dropped it. **Fix: macrecomp #3.**

## 3. Picking Skip quit the game

With clicks delivered, picking Skip logged `boot: main returned`. The trace
ended in two `$A032` (FlushEvents). It is an OS trap: THINK C's glue
(`fn_2_0028`) pops the masks into D0, re-pushes the return address and traps.
The runtime popped 4 bytes, which was that return address. **Fix: macrecomp #3.**

## 4. The table faded in to black

The match screen stayed black but for the dirty rectangles. `MRBMSHOT` of
`805680` showed the table drawn correctly; the composite was black. Between the
two, each frame of the fade-in is `GetPattern` (PAT 2300-2310), `PenPat`,
`PaintRect` over the composite. GetPattern returned solid black for every id
and PenPat ignored its argument. Then the sprites drew as boxes: `MRGFX` showed
each as a `mode=3` (srcBic, the mask) and `mode=1` (srcOr, the image) pair, and
CopyBits did srcCopy for both. **Fix: macrecomp #4.**

## 5. The paddle was a sliver

The paddle tracked the mouse (`MRWATCHADDR=1ff96d`: a5-0x694 swung 80 to 186)
but drew 4 pixels wide, or 0, or -4. Its half-width, a5-0x696, was never
written by anything (`MRWATCHADDR=1ff96a`: no hits). Its defaults live in the
18-byte settings block at a5-0x6a6, and `DATA 0` holds them at offset 0xa4
(nine words, the last of them 50: the half-width).

THINK C applications initialise their globals at startup from `DATA 0`/`ZERO 0`
(and string literals from `STRS 0`). The original start-up path runs that
before main; `main.c` stands in for the protection loader and called main
directly, so every initialised global was zero. The startup is the game's own code in
CODE 1:

- `0x340` loads `STRS 0` into a NewPtr block and returns it in A4; the startup
  keeps A4 in CODE 1's first long.
- `0xb8` walks DATA a word at a time from `CurStackBase` (`$908`) up to A5,
  copying each word; a zero word is followed by a run of zeros whose length is
  the next `ZERO` word (its `dbra` is entered at the test, so n bytes, not n+1).
  DREL relocations follow (empty here).

Shufflepuck's globals are 0xe2c bytes, which puts DATA offset 0xa4 exactly at
a5-0x6a6. **Fix: `src/main.c` sets `$908` and calls both routines before main.**

## 6. Serving needs a long stroke

The paddle's depth is the mouse's place inside a 300-pixel box that follows the
mouse (`fn_5_363a`), so a 140-pixel push stops short of the puck. The
conformance script pushes from v=340 to v=0 in 1 s.
