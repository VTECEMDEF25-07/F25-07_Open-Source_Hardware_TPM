/* DE25 RevD dedicated HPS peripherals, after validated first-stage cold init. */
#include "lcd_status.h"
#include "de25_mmio.h"
#define CM 0x10d10000UL
#define UART 0x10c02100UL
#define SPI 0x10da4000UL
#define GPIO 0x10c03300UL
#define RESET (1U<<10)
#define DC (1U<<11)
#define BACKLIGHT (1U<<18)
static inline uint32_t rd(uintptr_t a) {return de25_rd(a);}
static inline void wr(uintptr_t a,uint32_t v) {de25_wr(a,v);}
static uint32_t hz;
static unsigned diag_enabled;
static unsigned diag_tx_failed;
volatile uint32_t lcd_exception_reported;
#ifdef DE25_HOST_TEST
uint64_t de25_test_ticks(void);
uint32_t de25_test_tick_hz(void);
uint64_t ticks(void) {return de25_test_ticks();}
uint32_t tick_hz(void) {return de25_test_tick_hz();}
#else
uint64_t ticks(void) {uint64_t n;__asm__ volatile("isb; mrs %0,cntpct_el0":"=r"(n));return n;}
uint32_t tick_hz(void) {uint64_t n;__asm__ volatile("mrs %0,cntfrq_el0":"=r"(n));return (uint32_t)n;}
#endif
static int delay_us(uint32_t us) {
    uint64_t start=ticks(),dt=((uint64_t)hz*us+999999)/1000000,last=start,now=start;
    unsigned budget=10000000,polled=0;
    lcd_uart_diag("DELAY_BEGIN",1,start,start,us);
    while((now=ticks())-start<dt){
        rx_pump();polled++;
        if((polled&4095U)==0){
            if(now==last){lcd_uart_diag("DELAY_NO_TICKS",0,start,now,polled);return 0;}
            last=now;
        }
        if(!--budget){lcd_uart_diag("DELAY_BUDGET",0,start,now,polled);return 0;}
    }
    lcd_uart_diag("DELAY_END",1,start,now,polled);return 1;
}
static uint32_t ho(unsigned off) {return __builtin_bswap32(rd(0x7f000UL+off));}
static uint32_t pll(unsigned globoff,unsigned moff) {
    uint32_t glob=rd(CM+globoff),src=(glob>>16)&3,div=(glob>>8)&15,m=rd(CM+moff)&1023;
    if(div==0 || m==0 || src>1)return 0;
    return (uint32_t)(((uint64_t)(src?460000000U:25000000U)*m)/div);
}
static uint32_t l3_clock(void) {
    uint32_t src=(rd(CM+0x40)>>16)&7,div,n;
    if(src==0){div=rd(CM+0x68)&2047;n=pll(0x48,0x6c);}
    else if(src==1){div=rd(CM+0xb4)&2047;n=pll(0x9c,0xc0);}
    else if(src==2)return 25000000U;
    else if(src==3)return 460000000U;
    else return 0; /* Never substitute EOSC for unknown FPGA reference. */
    return div?n/div:0;
}
uint32_t board_init(void) {
    /* Error codes remain inspectable in lcd_diag even without a live UART. */
    uint32_t init_error=de25_cold_init();if(init_error)return init_error;
    hz=tick_hz();if(hz<1000 || hz>1000000000U)return 1;
    if(ho(0)!=0x424f4f54 || ho(0x580)!=0x434c4b53 || ho(0x60c)!=25000000)return 2;
    if(rd(CM)&1)return 3; /* Boot clock mode: cold-start port still required. */
    if(rd(CM+0x30) || rd(CM+0x88))return 4; /* Reject bypassed PLLs. */
    /* No reset/pinmux/firewall writes in this image: prior DE25 startup must
     * configure these exact dedicated functions. Require out-of-reset state. */
    if((rd(0x10d11024)&(1U<<17)) || (rd(0x10d11028)&((1U<<17)|(1U<<25))))return 5;
    uint32_t l3=l3_clock(),uartclk=l3>>((rd(CM+0x44)>>6)&3);
    if(l3<1000000 || uartclk<1843200)return 6;
    uint32_t divisor=(uartclk+921600U)/1843200U;
    if(divisor==0 || divisor>65535)return 7;
    if(l3!=400000000U || uartclk!=100000000U)return 8;
    uint64_t counter_start=ticks();unsigned spins=1000000;
    while(ticks()==counter_start && --spins) {}
    if(!spins)return 10; /* Fail instead of entering an unbounded delay loop. */
    wr(UART+4,0);wr(UART+12,0x80);wr(UART,divisor&255);wr(UART+4,divisor>>8);wr(UART+12,3);wr(UART+8,7);
    uint32_t baud=((l3+499999U)/500000U+1U)&~1U;
    if(baud<2 || baud>65534)return 9;
    wr(SPI+8,0);wr(SPI, (7U<<16)|7U|(1U<<8)); /* Both DFS fields=8, TX-only, mode0. */
    wr(SPI+0x2c,0);wr(SPI+0x14,baud);wr(SPI+0x10,1);wr(SPI+8,1);
    wr(GPIO,(rd(GPIO)|RESET)&~(DC|BACKLIGHT));
    wr(GPIO+4,rd(GPIO+4)|RESET|DC|BACKLIGHT);
    return 0;
}
int uart_read(void) {uint32_t lsr=rd(UART+0x14);if(lsr&0x1e){if(lsr&1)(void)rd(UART);return 256;}return (lsr&1)?(int)(rd(UART)&255):-1;}
void uart_puts(const char *s) {
    while(*s) {uint64_t start=ticks();unsigned budget=1000000;while(!(rd(UART+0x14)&32)){rx_pump();if(!--budget || ticks()-start>hz/10)return;}
        wr(UART,(unsigned char)*s++);rx_pump();}
}
/* Diagnostic TX intentionally has no generic-counter deadline dependency. */
static void diag_puts(const char *s) {
    if(diag_tx_failed)return;
    while(*s){unsigned budget=1000000;
        while(!(rd(UART+0x14)&32)){rx_pump();if(!--budget){diag_tx_failed=1;return;}}
        wr(UART,(unsigned char)*s++);rx_pump();
    }
}
static void diag_hex(uint64_t n,unsigned digits) {
    char s[17];for(unsigned i=0;i<digits;i++)s[i]="0123456789ABCDEF"[(n>>((digits-1-i)*4))&15];s[digits]=0;diag_puts(s);
}
/* Fatal path: no RX pump, timer, parser, heap, or normal diagnostic state.
 * Assembly guards stage>=2 and one attempt; a nested fault parks immediately. */
static int fatal_puts(const char *s) {
    while(*s){unsigned budget=1000000;
        while(!(rd(UART+0x14)&32))if(!--budget)return 0;
        wr(UART,(unsigned char)*s++);
    }return 1;
}
static int fatal_hex(uint64_t n) {
    char s[17];for(unsigned i=0;i<16;i++)s[i]="0123456789ABCDEF"[(n>>((15-i)*4))&15];s[16]=0;
    return fatal_puts(s);
}
void lcd_exception_uart(uint64_t esr,uint64_t elr,uint64_t far,uint64_t sctlr,uint64_t fault_sp) {
    if(!fatal_puts("LCD_EXCEPTION ESR=") || !fatal_hex(esr))return;
    if(!fatal_puts(" ELR=") || !fatal_hex(elr))return;
    if(!fatal_puts(" FAR=") || !fatal_hex(far))return;
    if(!fatal_puts(" SCTLR=") || !fatal_hex(sctlr))return;
    if(!fatal_puts(" SP=") || !fatal_hex(fault_sp))return;
    (void)fatal_puts("\r\n");
}
void lcd_uart_diag(const char *tag,uint32_t ok,uint64_t t0,uint64_t t1,uint32_t detail) {
    if(!diag_enabled)return;
    diag_puts("LCD_DIAG ");diag_puts(tag);diag_puts(" S=");diag_hex(lcd_diag.stage,8);
    diag_puts(" E=");diag_hex(lcd_diag.error,8);diag_puts(" OK=");diag_hex(ok,8);
    diag_puts(" T0=");diag_hex(t0,16);diag_puts(" T1=");diag_hex(t1,16);
    diag_puts(" D=");diag_hex(detail,8);diag_puts("\r\n");
}
int lcd_diag_begin(void) {
    diag_enabled=1;diag_tx_failed=0;uint64_t t0=ticks();
    diag_puts("LCD_DIAG UART_CLOCK_PROBE ...............................................................\r\n");
    uint64_t t1=ticks();if(t1==t0)lcd_diag.error=22;
    lcd_uart_diag("COUNTER_PROBE",t1!=t0,t0,t1,tick_hz());
    /* PLAT_TIMER_BASE_ADDR/CNTCR0 matches pinned official SoCFPGA timer init.
     * Readback only: no enable/frequency/clock/reset change in this diagnostic. */
    diag_puts("LCD_DIAG CNTCR=");diag_hex(rd(0x10d01000),8);diag_puts("\r\n");
    if(diag_tx_failed){lcd_diag.error=23;return 0;}
    return t1!=t0;
}
void lcd_diag_quiet(void) {diag_enabled=0;}
static void trace_step(const char *tag) {uint64_t t=ticks();lcd_uart_diag(tag,1,t,t,0);}
static void gpio(uint32_t mask,int set) {wr(GPIO,set?rd(GPIO)|mask:rd(GPIO)&~mask);}
static int send(const uint8_t *p,unsigned n,int data) {
    unsigned requested=n;uint64_t begin=ticks();
    lcd_uart_diag("SPI_BEGIN",1,begin,begin,(n&65535U)|((unsigned)data<<16));
    gpio(DC,data);
    while(n) {
        unsigned chunk=n>16?16:n;uint64_t start=ticks();unsigned budget=1000000;
        uint32_t initial_sr=rd(SPI+0x28);
        if(!(initial_sr&2))lcd_uart_diag("SPI_TNF_WAIT",1,begin,ticks(),initial_sr);
        for(unsigned i=0;i<chunk;i++) {while(!(rd(SPI+0x28)&2)){rx_pump();if(!--budget || ticks()-start>hz/10){lcd_uart_diag("SPI_TNF_FAIL",0,begin,ticks(),rd(SPI+0x28));return 0;}}wr(SPI+0x60,*p++);}
        initial_sr=rd(SPI+0x28);
        if((initial_sr&5)!=4)lcd_uart_diag("SPI_BUSY_WAIT",1,begin,ticks(),initial_sr);
        while((rd(SPI+0x28)&5)!=4){rx_pump();if(!--budget || ticks()-start>hz/10){lcd_uart_diag("SPI_BUSY_FAIL",0,begin,ticks(),rd(SPI+0x28));return 0;}}
        rx_pump();n-=chunk;
    }
    lcd_uart_diag("SPI_END",1,begin,ticks(),requested);
    return 1;
}
int lcd_init(void) {
    static const uint8_t zero[132]={0};uint8_t c[]={0xae,0xc8,0x2f,0x40};
    trace_step("RESET_LOW_BEFORE");
    gpio(RESET,0);trace_step("RESET_LOW_AFTER");
    if(!delay_us(62500))return 0;
    trace_step("RESET_HIGH_BEFORE");
    gpio(RESET,1);trace_step("RESET_HIGH_AFTER");
    if(!delay_us(62500))return 0;
    if(!send(c,sizeof c,0) || !delay_us(20000))return 0;
    trace_step("PRE_PAGE");
#ifndef DE25_HOST_TEST
    {uint64_t ctl;__asm__ volatile("mrs %0,sctlr_el3":"=r"(ctl));
     lcd_uart_diag("PRE_PAGE_SCTLR",1,ctl,ctl,0);}
#endif
    for(unsigned page=0;page<8;page++){uint8_t a[]={(uint8_t)(0xb0+page),0x10,0};if(!send(a,3,0)||!send(zero,132,1))return 0;}
    c[0]=0xaf;if(!send(c,1,0))return 0;gpio(BACKLIGHT,1);
    trace_step("LCD_INIT_END");return 1;
}
int lcd_frame(const uint8_t *f) {
    for(unsigned page=0;page<8;page++){uint8_t a[]={(uint8_t)(0xb0+page),0x10,0};if(!send(a,3,0)||!send(f+128*page,128,1))return 0;}
    return 1;
}
