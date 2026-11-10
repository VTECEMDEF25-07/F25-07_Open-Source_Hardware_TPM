#include "lcd_status.h"
volatile struct lcd_diagnostics lcd_diag;
volatile uint64_t lcd_exception[3]; /* Fatal ESR, ELR, FAR captured by vectors. */
static char line[256]; static unsigned used,discard;
static struct snapshot latest; static int have,dirty; static uint64_t last;
void rx_pump(void) {
    int c;
    /* Bound cooperative work even if the sender streams continuously. */
    for(unsigned drained=0;drained<64 && (c=uart_read())>=0;drained++) {
        if(c>255) {discard=1;used=0;lcd_diag.overruns++;continue;}
        if(c=='\n') {
            line[used]=0; struct snapshot next;
            if(!discard && parse_snapshot(line,&next)) {latest=next;have=1;last=ticks();dirty=1;lcd_diag.accepted++;}
            else lcd_diag.rejected++;
            used=discard=0;
        } else if(!discard) {
            if(c==0 || used==sizeof(line)-1) {used=0;discard=1;}
            else line[used++]=(char)c;
        }
    }
}
int main(void) {
    static uint8_t frame[1024];
    lcd_diag.magic=0x4c434430; lcd_diag.stage=1;
    lcd_diag.error=board_init(); if(lcd_diag.error)return 1;
    lcd_diag.stage=2;uart_puts("DE25 LCD OCRAM UART1 - FRAME_SENT IS NOT GLASS PASS\r\n");
    if(!lcd_diag_begin())return 1;
    if(!lcd_init()){lcd_diag.error=20;lcd_uart_diag("MAIN_INIT_FAIL",0,0,0,0);return 1;}
    lcd_diag.stage=3;dirty=1;int was_stale=-1;
    for(;;) {
        rx_pump(); int stale=have && (ticks()-last)>((uint64_t)tick_hz()*2);
        if(dirty || stale!=was_stale) {
            /* Freeze source tuple/frame; RX may update latest during SPI bursts. */
            struct snapshot s=latest; int captured_have=have;dirty=0;
            render_status(frame,captured_have?&s:0,stale);
            if(!lcd_frame(frame)){lcd_diag.error=21;lcd_uart_diag("MAIN_FRAME_FAIL",0,0,0,0);return 1;}
            lcd_diag.frames++;lcd_diag.sequence=captured_have?s.sequence:0;
            char ack[]="FRAME_SENT 00000000\r\n";
            for(unsigned i=0;i<8;i++)ack[11+i]="0123456789ABCDEF"[(lcd_diag.sequence>>((7-i)*4))&15];
            uart_puts(ack);lcd_diag_quiet();was_stale=stale;
        }
    }
}
