/* DE25 RevD HPS-only first-stage initialization.
 * Pin/clock facts: generated Pro26.1 QIP + installed Agilex5 SVD, audited offline.
 * PLL ordering: pinned official Altera MIT-0 helpers / Trusted Firmware-A.
 * No DDR, FPGA bridge, fabric PLL, fan, SD, QSPI or mailbox command. */
#include "de25_mmio.h"
#include "de25_handoff_facts.h"
#include "pll_helpers.h"

static uint32_t handoff[DE25_HANDOFF_WORDS];
struct pin_section {uint32_t magic_at,magic,array_at,count;const uint16_t *offsets;uintptr_t target;};
static const struct pin_section sections[]={
    {0x10,0x504d5558,0x20,48,sel_offsets,0x10d13000},
    {0x1a0,0x494f4354,0x1b0,48,io_offsets,0x10d13130},
    {0x330,0x46504741,0x340,22,fpga_offsets,0x10d13300},
    {0x3f0,0x444c4159,0x400,48,delay_offsets,0x10d13400}
};

uint32_t de25_validate_handoff(const uint32_t *h) {
    if(h[0]!=0x424f4f54 || h[0x580/4]!=0x434c4b53)return 100;
    if(h[0x620/4]!=0x50455249 || h[0x634/4]!=0x5344524d || h[0x644/4]!=0)return 101;
    /* SDM options specify all HPS peripheral power domains on. No PWRMGR
     * override is needed for this OCRAM payload or the three peripherals. */
    if(h[0x630/4]!=255)return 102;
    for(unsigned s=0;s<4;s++) {
        const struct pin_section *p=&sections[s];uint64_t seen=0;
        if(h[p->magic_at/4]!=p->magic)return 110+s;
        /* Fixed array bounds come from the official handoff structure. The
         * length field is not used to control reads or register writes. */
        for(unsigned i=0;i<p->count;i++) {
            uint32_t off=h[p->array_at/4+2*i],val=h[p->array_at/4+2*i+1];unsigned k;
            for(k=0;k<p->count && p->offsets[k]!=off;k++) {}
            if(k==p->count || (seen&(1ULL<<k)))return 120+s;
            seen|=1ULL<<k;
            if(s==0 && val!=expected_pinsel[k])return 130;
            if((s==2 || s==3) && val!=0)return 131+s;
            /* IO-control words are fitter-derived electrical settings. Replay
             * the actual trusted SDM values only at the exact SVD whitelist.
             * Do not invent them from the pre-fit XML or mask reserved bits. */
        }
    }
    for(unsigned i=0;i<33;i++) {
        uint32_t v=h[0x590/4+i];const struct clock_fact *f=&clock_facts[i];
        if((v&f->mask)!=f->value || (v&~f->allowed))return 140+i;
    }
    return 0;
}

static void access_mpu(uintptr_t a) {de25_wr(a,de25_rd(a)|1U);}
static void replay_pins(const uint32_t *h) {
    for(unsigned s=0;s<4;s++) {
        const struct pin_section *p=&sections[s];
        for(unsigned i=0;i<p->count;i++)de25_wr(p->target+h[p->array_at/4+2*i],h[p->array_at/4+2*i+1]);
    }
    /* Dedicated IO only: both peripheral FPGA-routing enables remain off. */
    de25_wr(0x10d1206c,0);de25_wr(0x10d12070,0);
}

static uint32_t clock_init(const uint32_t *v) {
    /* Preserve SDM software boot-clock control bits8/9. Never replay a fixed
     * kit PLL recipe; every programmed divider comes from validated handoff. */
    cm_set(CM_CTRL,CM_CTRL_BOOTMODE);
    cm_set(CM_M_BYPASS,CM_BYP_MAIN_ALL);if(cm_wait_fsm())return 180;
    cm_set(CM_P_BYPASS,CM_BYP_PER_ALL);if(cm_wait_fsm())return 181;
    cm_clr(CM_M_PLLGLOB,CM_GLOB_PD_N|CM_GLOB_RST_N);
    cm_clr(CM_P_PLLGLOB,CM_GLOB_PD_N|CM_GLOB_RST_N);
    cm_wr(CM_M_PLLGLOB,v[2]&~CM_GLOB_RST_N);
    cm_wr(CM_M_FDBCK,v[3]);cm_wr(CM_M_VCOCALIB,cm_vcocalib(v[8],v[2]));
    for(unsigned i=4;i<9;i++)cm_wr(clock_facts[i].offset+CM_BASE,v[i]);
    cm_wr(CM_M_NOCCLK,v[0]);cm_wr(CM_M_NOCDIV,v[1]);
    cm_wr(CM_P_PLLGLOB,v[11]&~CM_GLOB_RST_N);
    cm_wr(CM_P_FDBCK,v[12]);cm_wr(CM_P_VCOCALIB,cm_vcocalib(v[17],v[11]));
    for(unsigned i=13;i<18;i++)cm_wr(clock_facts[i].offset+CM_BASE,v[i]);
    cm_wr(0x10d10094,v[9]);cm_wr(0x10d10098,v[10]);
    /* Only DSU/CPU counters are required. Unused Ethernet/USB/user/debounce
     * counters remain at reset; there is no generated fabric user clock. */
    for(unsigned i=26;i<31;i++)cm_wr(clock_facts[i].offset+CM_BASE,v[i]);
    cm_set(CM_M_PLLGLOB,CM_GLOB_PD_N|CM_GLOB_RST_N);
    cm_set(CM_P_PLLGLOB,CM_GLOB_PD_N|CM_GLOB_RST_N);
    if(cm_pll_pd_state(CM_M_MEM,CM_M_MEMSTAT))return 182;
    if(cm_pll_pd_state(CM_P_MEM,CM_P_MEMSTAT))return 183;
    for(unsigned i=0;i<4;i++){cm_set(CM_M_PLLC0+4*i,CM_PLLCX_EN);cm_set(CM_P_PLLC0+4*i,CM_PLLCX_EN);}
    if(cm_wait_lock())return 184;
    cm_set(CM_M_LOSTLOCK,CM_LOSTLOCK_BYPCLR);cm_set(CM_P_LOSTLOCK,CM_LOSTLOCK_BYPCLR);
    cm_set(CM_M_PLLGLOB,CM_GLOB_CLR_LL_BYP);cm_set(CM_P_PLLGLOB,CM_GLOB_CLR_LL_BYP);
    de25_wr(0x10d12204,v[31]);de25_wr(0x10d12208,v[32]);
    cm_clr(CM_M_BYPASS,CM_BYP_MAIN_ALL);if(cm_wait_fsm())return 185;
    cm_clr(CM_P_BYPASS,CM_BYP_PER_ALL);if(cm_wait_fsm())return 186;
    cm_wr(CM_INTRCLR,CM_INTRCLR_MLOST|CM_INTRCLR_PLOST);
    /* Explicit gates: core0/L4_MAIN/L4_SP, UART1 and SPI master0 only. */
    cm_set(CM_BASE+0x24,(1U<<8)|(1U<<3)|(1U<<1));
    cm_set(CM_BASE+0x7c,(1U<<21)|(1U<<9));
    /* DSU and CPU counter resets only; leave unrelated counters untouched. */
    cm_clr(CM_C_EXTCNTRST,(1U<<10)|(1U<<11)|(1U<<12)|(1U<<13));
    cm_clr(CM_CTRL,CM_CTRL_BOOTMODE);
    return 0;
}

uint32_t de25_cold_init(void) {
    if(!de25_entry_contract())return 90;
    for(unsigned i=0;i<DE25_HANDOFF_WORDS;i++)handoff[i]=__builtin_bswap32(de25_rd(0x7f000+4*i));
    uint32_t error=de25_validate_handoff(handoff);if(error)return error;
    /* Allow only MPU access to needed L4 endpoints; no FPGA2SOC/debug grants
     * and no blanket bridge/firewall opening. All writes preserve other bits. */
    static const uintptr_t access[]={0x10d2114c,0x10d21154,0x10d21158,0x10d2115c,
        0x10d2101c,0x10d21048,0x10d21070};
    for(unsigned i=0;i<sizeof access/sizeof access[0];i++)access_mpu(access[i]);
    replay_pins(handoff);
    error=clock_init(handoff+0x590/4);if(error)return error;
    /* Release only SPI master0, UART1 and GPIO1; never bridge/EMIF/fan reset. */
    cm_clr(0x10d11024,1U<<17);
    cm_clr(0x10d11028,(1U<<17)|(1U<<25));
    /* Generated NOC is400MHz; official Agilex5 system counter uses this rate.
     * Board code subsequently checks the live divider chain and counter ticks. */
    de25_timer_start(400000000U);
    return 0;
}
