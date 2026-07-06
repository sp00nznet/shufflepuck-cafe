/* Shufflepuck Cafe recomp - loader + entry.
 *
 * Lays out a flat 68k address space, loads the decrypted CODE segments and the
 * A5 jump table, wires inter-segment dispatch, and calls the game's main
 * (fn_2_3834 - the function that runs InitGraf/InitFonts/.../InitCursor).
 * Reads the decrypted segments from work/unpacked/ (produced by build.sh). */
#include "macrecomp/m68k.h"
#include "macrecomp/toolbox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void register_seg_1(uint32_t base);
void register_seg_2(uint32_t base);
void register_seg_5(uint32_t base);

/* flat address-space layout */
enum {
    STACK_TOP = 0x00180000,
    A5_BASE   = 0x00200000,
    SEG1      = 0x00300000,
    SEG2      = 0x00310000,
    SEG5      = 0x00340000,
    MEM_SIZE  = 0x02000000,          /* 32 MB */
    MAIN_OFF  = 0x3838,              /* game main: the InitGraf/.../InitCursor sequence */
};

static uint32_t seg_base(int s){ return s==1?SEG1 : s==2?SEG2 : s==5?SEG5 : 0; }

static long load(const char *dir, const char *name, uint8_t *dst, long max){
    char path[512]; snprintf(path,sizeof path,"%s/%s",dir,name);
    FILE *f=fopen(path,"rb"); if(!f){ fprintf(stderr,"missing %s\n",path); exit(2); }
    long n=fread(dst,1,max,f); fclose(f); return n;
}

int main(int argc, char **argv){
    const char *dir = argc>1 ? argv[1] : "work/unpacked";
    M.memsize = MEM_SIZE;
    M.mem = (uint8_t*)calloc(1, MEM_SIZE);
    if(!M.mem){ perror("mem"); return 1; }

    /* load decrypted segment code (drop the 4-byte seg header) */
    static uint8_t buf[0x20000];
    for(int i=0;i<3;i++){
        int s = (int[]){1,2,5}[i]; char nm[32]; snprintf(nm,sizeof nm,"CODE_%d.dec.bin",s);
        long n=load(dir,nm,buf,sizeof buf);
        memcpy(M.mem + seg_base(s), buf+4, n-4);
    }
    /* load CODE 0: A5 jump table + wire inter-segment dispatch */
    long c0=load(dir,"CODE_0.dec.bin",buf,sizeof buf);
    uint32_t jtoff = (buf[12]<<24)|(buf[13]<<16)|(buf[14]<<8)|buf[15];
    uint32_t jtlen = (buf[8]<<24)|(buf[9]<<16)|(buf[10]<<8)|buf[11];
    memcpy(M.mem + A5_BASE + jtoff, buf+16, c0-16);        /* jump table into A5 world */
    for(uint32_t i=0;i*8<jtlen;i++){
        uint8_t *e=buf+16+i*8;
        uint16_t off=(e[0]<<8)|e[1], push=(e[2]<<8)|e[3], seg=(e[4]<<8)|e[5], trap=(e[6]<<8)|e[7];
        if(push==0x3F3C && trap==0xA9F0 && seg_base(seg))
            m68k_jt_set(jtoff + i*8, seg_base(seg) + off);
    }

    register_seg_1(SEG1); register_seg_2(SEG2); register_seg_5(SEG5);
    toolbox_init();
    plat_open("Shufflepuck Cafe", 2);

    M.a[5] = A5_BASE;
    SP     = STACK_TOP;

    fprintf(stderr, "boot: calling game main (fn_2_%04x)...\n", MAIN_OFF);
    m68k_call(SEG2 + MAIN_OFF);
    fprintf(stderr, "boot: main returned\n");

    plat_present();
    plat_shutdown();
    return 0;
}
