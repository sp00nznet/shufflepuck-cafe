# The copy protection, reverse-engineered

*Shufflepuck Cafe* ships with **"HLS Duplication"** copy protection (the string is
right there in the decrypted loader table). Its 68k code is **encrypted at rest**
inside the `CODE` resources and unpacked at launch by a plaintext loader in
**CODE 4**. This is why a naive disassembly of `CODE 1/2/5` is noise, and why the
Phase-2 trap scan of the raw segments was meaningless.

Reversed statically with `ext/macrecomp/tools/{disasm_code,unprotect}.py`. Status:
**jump table cracked and verified; segment-body cipher still being traced.**

## The loader (CODE 4, plaintext)

The app's initial jump-table entry (CODE 0 entry 0, the only plaintext one)
points at **segment 4, offset 0x42**. CODE 4 is the decryptor. Reading it:

| Stage | CODE 4 offset | What it does |
|------:|---------------|--------------|
| 1 | 0x46 | **Self-decrypts a local table** by negating the words in seg `[0x02,0x42)` (`neg.w (a0)+ / cmpa.l a0,a1 / bne`). Reveals a jump-table thunk + the strings `"Shufflepuck Cafe"`, `"HLS Duplication"`, and a helper that computes a loop count `d5 = (a1-a0)/2 - 1`. |
| 2 | 0x58 | `_NewPtr $400`, fills 512 words with `NOP` + a trailing `RTS`, then `jsr (a3)` into it — an **anti-debug / timing** no-op sled, later `_DisposePtr`'d. |
| 3 | 0x90 | `_GetResource('CODE', id)` (id from a global at A5+0x20). |
| 4 | 0xd0 | **Decrypts the A5-world jump table** (A5+0x28 … A5+0x868) — see below. |
| 5 | 0xb6, 0x138 | A 16-iteration LFSR/CRC (`lsl d1 / roxr d2 / eor d2,d0 / lsl d0 / bcc / eor d3,d0`) — a second decrypt pass, keyed by a polynomial in `d3`. |
| 6 | 0xfe | **Patches traps** `_GetResource ($A9A0)`, `_ExitToShell ($A9F4)`, `$A9F2` to game routines via `_GetTrapAddress`/`_SetTrapAddress`, so segment loads decrypt lazily. |
| 7 | 0x15e | `jmp $85a(a5)` — into the real game entry. |

On any failure it `_SysError`s and `_ExitToShell`s (stage at 0xf2).

## Jump-table cipher — SOLVED ✅

CODE 0 = 16-byte A5 header + 265 eight-byte jump-table entries. **Entry 0 is
plaintext**; entries 1..264 are decrypted in memory (from A5+0x28) by an
`eor` + additive forward chain:

```
key = 0xF55C
a0  = &entry1                       # A5+0x28  == CODE0 body offset 8
repeat 0x420 times (all remaining words):
    d3         = *a0 ^ key          # (post-increment read)
    *(a0)     += d3                 # add into the NEXT word
```

Replaying that (`unprotect.py: decrypt_jump_table`) turns the ciphertext into
valid unloaded thunks — `<offset> 3F3C <seg> A9F0` (`MOVE.W #seg,-(SP); _LoadSeg`):

```
entry1: off=0x0128 seg=1   entry2: off=0x013c seg=1   …   entry10: off=0x0d9e seg=2
```

**230 / 265** entries recover as clean thunks. The recovered **function
directory** — every routine's segment + offset — is written to
`work/unpacked/jumptable.json`:

| segment | functions | (encrypted body size) |
|--------:|----------:|-----------------------|
| 1 | 9 | 996 B |
| 2 | 141 | 23,006 B |
| 3 | 2 | 32 B |
| 4 | 1 | 1,322 B (the loader) |
| 5 | 77 | 26,710 B |

~230 functions total, concentrated in the two big logic segments (2 and 5).
The ~35 unresolved tail entries are finished by the loader's **second pass**
(the 0x138 LFSR), not yet replicated.

## Segment-body cipher — SOLVED ✅

The decrypted jump table doesn't just list functions — ~35 of its "entries" are
actually **plaintext handler code embedded in the A5 world**. One of them, at
**A5+0x750**, is the `_GetResource` hook the loader installs. Disassembling it
(it's already decrypted) gave the exact body cipher. For each `CODE` resource
loaded:

```
seed = (header_word  with bit 14 cleared) ^ resourceID      # the handler's `bclr #6,$2(a1)`
K    = crc16(seed, key_material = handler code A5+0x750..0x868, poly $32E6)
body: for (size/2 - 2) words starting at CODE+2:            # skip words that are 0
        next += (cur ^ K)                                    #  (same additive chain, per-segment key K)
```

The per-segment key `K` is a 16-bit CRC of the handler's *own* code (constant),
seeded by the segment's header word and resource id. Recovered keys:

| CODE | resID | seed | key K |
|-----:|------:|------|-------|
| 1 | 1 | `$000B` | `$02AE` |
| 2 | 2 | `$008F` | `$CF4C` |
| 5 | 5 | `$0048` | `$4900` |

### How it was cracked

Reading the handler gave the algorithm, but the CRC's exact bit-mixing
(`roxr`/X-flag) was easy to get subtly wrong by hand — and no hand-reconstruction
decrypted the bodies. The tie-breaker was **running the real handler in Ghidra's
p-code emulator** (`ext/macrecomp/tools/ghidra/EmuDecrypt.java`): the CRC+decrypt
span is pure arithmetic (no traps), so with the right register/memory setup the
actual 68000 code decrypts the segment for us. That gave ground-truth plaintext
(and the true key `$CF4C`), which pinned down the one-line CRC bug. The final
`unprotect.py` is **pure Python and byte-exact** against the emulator output — no
emulator needed to reproduce it.

Result: `CODE 1/2/5` decrypt to **94–97%** valid-instruction density (matching a
known-good control), and the real Toolbox trap set is now readable — see
[CLASSIFY.md](CLASSIFY.md).

## Segment sizes

| CODE | bytes | role |
|-----:|------:|------|
| 0 | 2,136 | A5 jump table (entry 0 plaintext; rest `$F55C`-chained) + embedded handlers |
| 1 | 996 | encrypted body, key `$02AE` |
| 2 | 23,006 | encrypted body, key `$CF4C` — core logic |
| 3 | 32 | encrypted, key `$000E` |
| 4 | 1,322 | **plaintext decryptor / segment loader** |
| 5 | 26,710 | encrypted body, key `$4900` — logic / physics / AI |
