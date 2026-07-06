# Phase 2 — Disassemble + classify (the go/no-go gate)

## Verdict: **GO — but the code is copy-protected and must be unpacked first.**

Shufflepuck Cafe ships a **self-decrypting segment loader**. The 68k code is
*encrypted at rest* inside the `CODE` resources; a small plaintext stub decrypts
and runs it at launch. So the size is tractable and the app is otherwise a
standard Toolbox program — but **nothing can be lifted until the CODE is
unpacked**, and the trap scan of the raw (encrypted) segments is meaningless.

This adds one milestone before lifting: **Phase 2.5 — unpack.**

## How we know (evidence)

Tools (now in `ext/macrecomp/tools`): `disasm_code.py`, `scan_traps.py`, `traps.json`.

1. **Pipeline is proven correct on a control.** The **Finder** from the same disk
   (unencrypted) disassembles cleanly — 95% valid instructions, real
   `jsr $NNN(a5)` jump-table calls, `_UnLoadSeg`, sane `rts` — and `scan_traps`
   yields a believable histogram (`SetPort`, `BlockMove`, `GetResource`,
   `NewHandle`, `FrameRect`, `MoveTo`…). So capstone + extraction are fine.

2. **Shufflepuck's CODE is not.** `CODE 1/2/5` bodies disassemble to noise
   (`CODE 1` begins `fd5c…`, a line-F illegal opcode). The **CODE 0 jump table**
   is scrambled *except entry 0*: entry 0 is a valid unloaded thunk
   (`0042 3F3C 0004 A9F0` = offset 0x42, `MOVE.W #4`, `_LoadSeg`), but entries 1+
   are `xxxx xxxx 35A1 B493` with a constant repeating tail — ciphertext.

3. **Entry 0 points at segment 4 — and CODE 4 is the plaintext decryptor.**
   The app's initial jump-table entry targets **seg 4, offset 0x42**. Disassembly
   of CODE 4 from there is coherent self-modifying loader code:

   ```
   neg.w  (a0)+ / cmpa.l a0,a1 / bne      ; decrypt a region in place
   move.l #$400,d0 / _NewPtr              ; allocate scratch
   … build a routine of NOPs + trailing RTS …
   jsr    (a3)                            ; run the built code
   _DisposePtr
   move.l #'CODE',-(a7) / … / _GetResource ; pull a CODE segment, decrypt it
   ```

   i.e. a runtime unpacker that `_GetResource`s each encrypted segment, transforms
   it, and dispatches — classic late-80s Mac protection.

4. **It is not a simple global cipher.** Tested identity / `neg.w` / `not` /
   `neg.b` / `xor $A5` / byte-swap on `CODE 1`; best score ~83% vs the 95%
   known-good baseline — i.e. none decrypt it. The scheme is the self-modifying,
   likely multi-stage / offset-keyed loader in CODE 4, not a one-shot XOR.

5. **The 24 KB data fork is game data, not code** — structured 16-bit tuples
   (`000d 0028 0048 00b8 001f 001f 0064 …`): coordinate / parameter tables
   (table geometry, opponent stats?). To be mapped after unpacking.

## What leaked through (weak signal only)

Even scanning ciphertext, the standard Toolbox init boilerplate surfaced in
plausible spots (`InitGraf _A86E`, `InitFonts _A8FE`, `InitWindows _A912`,
`InitMenus _A930`, `InitDialogs _A97B`, `TEInit _A9CC`, `InitCursor _A850`,
`GetNextEvent _A970`, `ModalDialog _A991`, `GetNewDialog`, `CopyBits _A8EC`).
Treat as a hint, not the trap set — the real enumeration must wait for unpacked
code. But it does suggest the eventual surface is ordinary (QuickDraw + events +
dialogs + sound), consistent with the Phase-0 read.

## Phase 2.5 — unpack (proposed)

Two ways to get plaintext CODE; they can be combined (dynamic to get ground
truth, static to make it reproducible):

**A. Dynamic snapshot (recommended).** Let the game decrypt itself and dump the
result — exactly how the Bolo recomp handled PKLITE. Stand up a 68k execution
harness (Musashi / Unicorn-m68k, or a scripted Mini vMac) with just enough
Toolbox for `_NewPtr`/`_GetResource`/`_LoadSeg`, run CODE 4's loader, and capture
the decrypted `CODE 0/1/2/5` from memory. You never reverse the crypto — the
program does it for you.

**B. Static reversal.** Fully reverse CODE 4's decryptor and reimplement it in
Python (a `tools/unprotect.py`, sibling of Bolo's `unpklite.py`). More brittle
against self-modifying / multi-stage logic, but yields a clean, dependency-free
one-shot unpacker and a written spec of the scheme.

Once unpacked: re-run `scan_traps` for the real trap set (the true Phase-4 cost),
rebuild the jump table, and proceed to Phase 3 lifting.

## Segment sizes (encrypted, on disk)

| CODE | bytes | role |
|-----:|------:|------|
| 0 | 2,136 | A5 jump table (entry 0 plaintext → seg 4 +0x42; rest encrypted) |
| 1 | 996 | encrypted |
| 2 | 23,006 | encrypted — core logic |
| 3 | 32 | small stub / key data |
| 4 | 1,322 | **plaintext decryptor / segment loader** |
| 5 | 26,710 | encrypted — logic / physics / AI |
