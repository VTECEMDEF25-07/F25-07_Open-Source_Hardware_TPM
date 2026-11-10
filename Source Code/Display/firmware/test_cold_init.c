#include "de25_mmio.h"
#include "de25_handoff_facts.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static uint32_t image[DE25_HANDOFF_WORDS];
static struct {uintptr_t a;uint32_t v;} writes[2048];
static unsigned nw,reads,stat_reads,scenario;
static int contract=1;
static uint32_t regvalue(uintptr_t a) {
    for(unsigned i=nw;i;i--)if(writes[i-1].a==a)return writes[i-1].v;
    if(a==0x10d10000)return 0x301;
    if(a==0x10d11024 || a==0x10d11028 || a==0x10d100f4)return 0xffffffff;
    return 0;
}
uint32_t de25_rd(uintptr_t a) {
    reads++;
    if(a>=0x7f000 && a<0x7f648)return __builtin_bswap32(image[(a-0x7f000)/4]);
    if(a==0x10d10004){stat_reads++;return scenario==1?1:scenario==4?0:scenario==5?(stat_reads%5?0x10100:0):0x10100;}
    if(a==0x10d10050 || a==0x10d100a4) return scenario==2?(1U<<24):scenario==3?(1U<<26):0;
    if(a==0x10d10054 || a==0x10d100a8)return 0x55;
    return regvalue(a);
}
void de25_wr(uintptr_t a,uint32_t v) {assert(nw<2048);writes[nw].a=a;writes[nw].v=v;nw++;}
int de25_entry_contract(void) {return contract;}
void de25_timer_start(uint32_t hz) {assert(hz==400000000);de25_wr(0x10d01000,3);}
static void setup(void) {
    memset(image,0,sizeof image);nw=reads=stat_reads=scenario=0;contract=1;
    image[0]=0x424f4f54;image[0x580/4]=0x434c4b53;
    image[0x620/4]=0x50455249;image[0x630/4]=255;
    image[0x634/4]=0x5344524d;image[0x644/4]=0;
    const unsigned magic_at[]={0x10,0x1a0,0x330,0x3f0};
    const uint32_t magic[]={0x504d5558,0x494f4354,0x46504741,0x444c4159};
    const unsigned array[]={0x20,0x1b0,0x340,0x400};
    const unsigned count[]={48,48,22,48};
    const uint16_t *offsets[]={sel_offsets,io_offsets,fpga_offsets,delay_offsets};
    for(unsigned s=0;s<4;s++) {
        image[magic_at[s]/4]=magic[s];
        for(unsigned i=0;i<count[s];i++){
            image[array[s]/4+2*i]=offsets[s][i];
            image[array[s]/4+2*i+1]=s==0?expected_pinsel[i]:s==1?0x00502c38U+i:0;
        }
    }
    for(unsigned i=0;i<33;i++)image[0x590/4+i]=clock_facts[i].value;
    image[0x590/4+2]|=0x10000003;image[0x590/4+11]|=0x10000003;
}
static int wrote(uintptr_t a) {for(unsigned i=0;i<nw;i++)if(writes[i].a==a)return 1;return 0;}
int main(void) {
    unsigned checks=0;
    setup();assert(de25_validate_handoff(image)==0);checks++;
    /* Every handoff offset must be a unique allowed register, including holes. */
    const unsigned array[]={0x20,0x1b0,0x340,0x400},count[]={48,48,22,48};
    for(unsigned s=0;s<4;s++)for(unsigned i=0;i<count[s];i++) {
        setup();image[array[s]/4+2*i]=0xfffffffc;
        assert(de25_cold_init()!=0 && nw==0);checks++;
    }
    for(unsigned s=0;s<4;s++) {
        setup();image[array[s]/4+2]=image[array[s]/4];
        assert(de25_cold_init()!=0 && nw==0);checks++;
    }
    const unsigned magics[]={0,0x10,0x1a0,0x330,0x3f0,0x580,0x620,0x634};
    for(unsigned i=0;i<8;i++){setup();image[magics[i]/4]^=1;assert(de25_cold_init()!=0 && !nw);checks++;}
    for(unsigned i=0;i<33;i++)if(clock_facts[i].mask) {
        setup();uint32_t bit=clock_facts[i].mask&-clock_facts[i].mask;
        image[0x590/4+i]^=bit;assert(de25_cold_init()!=0 && !nw);checks++;
    }
    setup();image[0x644/4]=1;assert(de25_cold_init()==101 && !nw);checks++;
    setup();image[0x630/4]=0;assert(de25_cold_init()==102 && !nw);checks++;
    setup();contract=0;assert(de25_cold_init()==90 && !reads && !nw);checks++;
    setup();image[0x20/4+2*38+1]=8;assert(de25_cold_init()==130 && !nw);checks++;
    setup();image[0x340/4+2*21+1]=1;assert(de25_cold_init()!=0 && !nw);checks++;
    setup();image[0x400/4+1]=1;assert(de25_cold_init()!=0 && !nw);checks++;
    /* Fault injection: no peripheral reset release/timer after any PLL failure. */
    for(unsigned s=1;s<=5;s++) {
        setup();scenario=s;assert(de25_cold_init()!=0);
        assert(!wrote(0x10d11024) && !wrote(0x10d11028) && !wrote(0x10d01000));
        assert(regvalue(0x10d10000)&1);checks++;
    }
    setup();assert(de25_cold_init()==0);checks++;
    assert(regvalue(0x10d11024)==(0xffffffffU&~(1U<<17)));checks++;
    assert(regvalue(0x10d11028)==(0xffffffffU&~((1U<<17)|(1U<<25))));checks++;
    assert(regvalue(0x10d10000)==0x300);checks++; /* Preserve SW boot-control bits. */
    assert(regvalue(0x10d1006c)==128 && regvalue(0x10d100c0)==120);checks++;
    assert(regvalue(0x10d10068)==(8|(1U<<27)));checks++;
    assert(regvalue(0x10d10024)==((1U<<8)|(1U<<3)|(1U<<1)));checks++;
    assert(regvalue(0x10d1007c)==((1U<<21)|(1U<<9)));checks++;
    assert(regvalue(0x10d13218)==0x00502c38U+34);checks++; /* Real IO-control holes. */
    for(unsigned i=0;i<nw;i++) {
        uintptr_t a=writes[i].a;
        assert(a!=0x10d1102c && !(a>=0x10d21200 && a<0x10d21500));
        assert(a!=0x10c02000 && a!=0x10d100e8 && a!=0x10d100ec); /* No UART0/user clocks. */
        if(a>=0x10d21000 && a<0x10d21200)assert(writes[i].v==1);
    }
    checks++;
    printf("PASS cold-init %u checks; invalid handoff causes zero writes; bounded PLL faults; narrow MMIO/reset trace\n",checks);
    return 0;
}
