/* Shufflepuck Cafe recomp - entry harness (Phase 3 skeleton).
 *
 * Sets up the m68k runtime, loads the (decrypted) CODE segments into flat
 * memory, and registers the lifted functions. Actually driving the game to a
 * window happens once the Toolbox HAL exists (Phase 4). For now this links the
 * whole lifted program and is the anchor the build compiles. */
#include "macrecomp/m68k.h"
#include <stdlib.h>
#include <stdio.h>

/* generated per-segment registration (src/gen/code_N.c) */
void register_seg_1(uint32_t base);
void register_seg_2(uint32_t base);
void register_seg_5(uint32_t base);

/* segment load bases in the flat address space (arbitrary, non-overlapping) */
enum { SEG1=0x100000, SEG2=0x110000, SEG5=0x140000 };

int main(void) {
    M.memsize = 16u * 1024 * 1024;
    M.mem = (uint8_t *)calloc(1, M.memsize);
    if (!M.mem) { perror("mem"); return 1; }

    register_seg_1(SEG1);
    register_seg_2(SEG2);
    register_seg_5(SEG5);

    printf("shufflepuck: runtime up, lifted functions registered.\n");
    printf("(Toolbox HAL / real execution: Phase 4-5)\n");
    return 0;
}
