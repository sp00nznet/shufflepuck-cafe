/* Shufflepuck Cafe recomp - loader + entry.
 *
 * Lays out a flat 68k address space, loads the decrypted CODE segments and the
 * A5 jump table, wires inter-segment dispatch, and calls the game's main
 * (fn_2_3a06: init, then the event loop).
 * Reads the decrypted segments from work/unpacked/ (produced by build.sh). */
#include "macrecomp/m68k.h"
#include "macrecomp/toolbox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>

void register_seg_1(uint32_t base);
void register_seg_2(uint32_t base);
void register_seg_3(uint32_t base);
void register_seg_5(uint32_t base);

/* flat address-space layout */
enum {
    STACK_TOP = 0x00180000,
    A5_BASE   = 0x00200000,
    SEG1      = 0x00300000,
    SEG2      = 0x00310000,
    SEG3      = 0x00350000,
    SEG5      = 0x00340000,
    MEM_SIZE  = 0x02000000,          /* 32 MB */
    MAIN_OFF  = 0x3a06,             /* fn_2_3a06 = real main (init + event loop) */
};

static uint32_t seg_base(int s){ return s==1?SEG1 : s==2?SEG2 : s==3?SEG3 : s==5?SEG5 : 0; }

static long load(const char *dir, const char *name, uint8_t *dst, long max){
    char path[512]; snprintf(path,sizeof path,"%s/%s",dir,name);
    FILE *f=fopen(path,"rb"); if(!f){ fprintf(stderr,"missing %s\n",path); exit(2); }
    long n=fread(dst,1,max,f); fclose(f); return n;
}

/* Bytes THINK C's DATA/ZERO initialiser (CODE 1 0xb8) writes below A5: each
 * DATA word is copied, and a zero word is followed by a run of zeros as long
 * as the next ZERO word (the run's dbra is entered at its test, so n, not n+1). */
static uint32_t globals_size(const char *dir){
    uint8_t d[4096], z[4096]; long nd, nz;
    char p[600]; FILE *f;
    snprintf(p,sizeof p,"%s/../rsrc/DATA_0.bin",dir); f=fopen(p,"rb"); nd=f?(long)fread(d,1,sizeof d,f):0; if(f)fclose(f);
    snprintf(p,sizeof p,"%s/../rsrc/ZERO_0.bin",dir); f=fopen(p,"rb"); nz=f?(long)fread(z,1,sizeof z,f):0; if(f)fclose(f);
    uint32_t size=0; long k=0;
    for(long i=0;i+1<nd;i+=2){
        size+=2;
        if(!d[i] && !d[i+1] && k+1<nz){ size+=(uint32_t)(z[k]<<8|z[k+1]); k+=2; }
    }
    return size;
}

/* Game state at exit, for the conformance harness: a5-0xc3c is the bar's
 * state (the picked opponent, 1 = Skip), a5-0x696 the paddle's half-width
 * (50 from the DATA defaults; 0 if the THINK C startup did not run), and
 * a5-0x694/-0x692 where the mouse has put the paddle, and the score as
 * opponent:you (a5-0xca6, a5-0xca8; first to 15 wins). */
static void report_state(void){
    fprintf(stderr, "[game] state=%d halfwidth=%d paddle=%d,%d score=%d:%d\n",
        (int16_t)m68k_r16(A5_BASE-0xc3c), (int16_t)m68k_r16(A5_BASE-0x696),
        (int16_t)m68k_r16(A5_BASE-0x694), (int16_t)m68k_r16(A5_BASE-0x692),
        (int16_t)m68k_r16(A5_BASE-0xca6), (int16_t)m68k_r16(A5_BASE-0xca8));
}

int main(int argc, char **argv){
    /* shufflepuck [--headless] [--record out.mp4] [--watchdog secs]
     *             [--move x,y@secs] [--click x,y@secs] [--key c@secs|^c@secs]
     *             [--stroke x0,y0:x1,y1@secs+dur] [work/unpacked]
     * A stroke glides the mouse in 1/30 s steps; serving needs one, and a match
     * of them as single moves runs past Windows' 32k command line. */
    const char *dir = "work/unpacked", *record = NULL;
    int headless = 0, watchdog = 0;
    for(int i=1;i<argc;i++){
        int x, y, x1, y1; double t, dur; char c;
        if(!strcmp(argv[i],"--headless")) headless = 1;
        else if(!strcmp(argv[i],"--record") && i+1<argc) record = argv[++i];
        else if(!strcmp(argv[i],"--watchdog") && i+1<argc) watchdog = atoi(argv[++i]);
        else if((!strcmp(argv[i],"--move") || !strcmp(argv[i],"--click")) && i+1<argc
                && sscanf(argv[i+1],"%d,%d@%lf",&x,&y,&t)==3){
            plat_script(argv[i][2]=='m' ? 'm' : 'c', x, y, t); i++; }
        else if(!strcmp(argv[i],"--stroke") && i+1<argc
                && sscanf(argv[i+1],"%d,%d:%d,%d@%lf+%lf",&x,&y,&x1,&y1,&t,&dur)==6){
            int n = dur > 0 ? (int)(dur*30) : 0;
            for(int k=0;k<=n;k++)
                plat_script('m', x + (x1-x)*k/(n?n:1), y + (y1-y)*k/(n?n:1), t + k/30.0);
            i++; }
        else if(!strcmp(argv[i],"--key") && i+1<argc && sscanf(argv[i+1],"^%c@%lf",&c,&t)==2){
            plat_script('k', (unsigned char)c, 1, t); i++; }     /* ^o: Command-O */
        else if(!strcmp(argv[i],"--key") && i+1<argc && sscanf(argv[i+1],"%c@%lf",&c,&t)==2){
            plat_script('k', (unsigned char)c, 0, t); i++; }
        else if(argv[i][0]=='-'){ fprintf(stderr,"unknown option %s\n",argv[i]); return 2; }
        else dir = argv[i];
    }
    plat_config(headless, record, watchdog);
    M.memsize = MEM_SIZE;
    M.mem = (uint8_t*)calloc(1, MEM_SIZE);
    if(!M.mem){ perror("mem"); return 1; }

    /* load decrypted segment code (drop the 4-byte seg header) */
    static uint8_t buf[0x20000];
    for(int i=0;i<4;i++){
        int s = (int[]){1,2,3,5}[i]; char nm[32]; snprintf(nm,sizeof nm,"CODE_%d.dec.bin",s);
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
            /* code jsr's to entry+2 (the `move.w #seg; _LoadSeg` thunk), not the
             * entry start (which holds the routine's offset word) */
            m68k_jt_set(jtoff + i*8 + 2, seg_base(seg) + off);
    }

    register_seg_1(SEG1); register_seg_2(SEG2); register_seg_3(SEG3); register_seg_5(SEG5);
    toolbox_init();
    /* the game opens its own data fork (GetAppParms, then _Open on that name);
     * without it the open fails and it raises "Sorry, this disk is full." */
    if(!getenv("MRAPP")) putenv("MRAPP=Shufflepuck Cafe");
    { char dp[600]; snprintf(dp,sizeof dp,"%s/../data_fork.bin",dir);
      FILE *f=fopen(dp,"rb"); long n=0;
      if(f){ fseek(f,0,SEEK_END); n=ftell(f); fclose(f); }
      else fprintf(stderr,"missing %s (rerun build.sh)\n",dp);
      fs_add("Shufflepuck Cafe","APPL","PUCK",dp,(uint32_t)n,NULL,0); }

    /* register the app's own resources (PICT/MENU/STR/…) from work/rsrc */
    { char rd[600]; snprintf(rd,sizeof rd,"%s/../rsrc",dir);
      DIR *d=opendir(rd); int nres=0; struct dirent *e;
      while(d && (e=readdir(d))){
          char nm[256]; strncpy(nm,e->d_name,sizeof nm-1); nm[sizeof nm-1]=0;
          char *dot=strstr(nm,".bin"); if(!dot) continue; *dot=0;
          char *us=strrchr(nm,'_'); if(!us) continue; int id=atoi(us+1); *us=0;
          char path[900]; snprintf(path,sizeof path,"%s/%s",rd,e->d_name);
          FILE *f=fopen(path,"rb"); if(!f) continue;
          fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
          uint8_t *b=(uint8_t*)malloc(n>0?n:1); if(fread(b,1,n,f)!=(size_t)n){} fclose(f);
          res_add(nm, id, b, (int)n); nres++;
      }
      if(d) closedir(d);
      fprintf(stderr,"loaded %d resources\n", nres);
    }
    plat_open("Shufflepuck Cafe", 2);

    M.a[5] = A5_BASE;
    SP     = STACK_TOP;

    /* THINK C's startup, which the protection loader ran before main and we
     * skip by calling main directly. Without it every initialised global is
     * zero -- the paddle's half-width among them, so the paddle drew as a
     * sliver. Run the game's own lifted routines (CODE 1): 0x340 loads STRS
     * into a heap block and returns it in A4, which the startup keeps in
     * CODE 1's first long; 0xb8 fills the globals from CurStackBase up to A5
     * out of DATA/ZERO (and DREL, empty here). We supply only CurStackBase,
     * which the Segment Loader would have set: A5 minus the globals' size. */
    m68k_w32(0x908, A5_BASE - globals_size(dir));
    M.d[6] = 0x53545253;                                   /* 'STRS' */
    m68k_call(SEG1 + 0x340);
    m68k_w32(SEG1, M.a[4]);
    m68k_call(SEG1 + 0xb8);

    atexit(report_state);
    fprintf(stderr, "boot: calling game main (fn_2_%04x)...\n", MAIN_OFF);
    m68k_call(SEG2 + MAIN_OFF);
    fprintf(stderr, "boot: main returned\n");

    plat_present();
    plat_shutdown();
    return 0;
}
