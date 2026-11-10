#include "lcd_status.h"
#include "de25_mmio.h"
#include "de25_handoff_facts.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#define SPI 0x10da4000UL
#define GPIO 0x10c03300UL
#define UART 0x10c02100UL
static uint32_t gpio_data=1U<<17,gpio_dir=1U<<9;
static uint64_t now;
static unsigned pulses,bytes,dc,display_on,page,column,mode,baud,dll,dlm;
static int stuck,rxbyte=-1,rxerror,stop_ticks;
static uint8_t ram[8][132];
uint32_t de25_cold_init(void) {return 0;}
void rx_pump(void) {pulses++;}
uint64_t de25_test_ticks(void) {if(!stop_ticks)now+=400000;return now;}
uint32_t de25_test_tick_hz(void) {return 400000000;}
uint32_t de25_rd(uintptr_t a) {
    if(a==0x7f000)return __builtin_bswap32(0x424f4f54);
    if(a==0x7f580)return __builtin_bswap32(0x434c4b53);
    if(a==0x7f60c)return __builtin_bswap32(25000000);
    if(a>=0x10d10000 && a<0x10d10110) {
        for(unsigned i=0;i<31;i++)if(clock_facts[i].offset+0x10d10000==a)return clock_facts[i].value;
        return 0;
    }
    if(a==GPIO)return gpio_data;
    if(a==GPIO+4)return gpio_dir;
    if(a==SPI+0x28)return stuck?1:6;
    if(a==UART+0x14)return 0x20|(rxbyte>=0?1:0)|(rxerror?2:0);
    if(a==UART){int n=rxbyte;rxbyte=-1;rxerror=0;return (uint32_t)n;}
    if(a==0x10d11024 || a==0x10d11028)return 0;
    assert(0 && "Unexpected peripheral read");return 0;
}
void de25_wr(uintptr_t a,uint32_t v) {
    if(a==GPIO){gpio_data=v;dc=!!(v&(1U<<11));return;}
    if(a==GPIO+4){gpio_dir=v;return;}
    if(a==SPI)mode=v;
    if(a==SPI+0x14)baud=v;
    if(a==UART)dll=v;
    if(a==UART+4)dlm=v;
    if(a==SPI+0x60) {
        bytes++;
        if(dc){assert(page<8 && column<132);ram[page][column++]=(uint8_t)v;}
        else if((v&0xf8)==0xb0){page=v&7;column=0;}
        else if((v&0xf0)==0x10)column=(column&15)|((v&15)<<4);
        else if((v&0xf0)==0)column=(column&0xf0)|(v&15);
        else if(v==0xaf){
            for(unsigned p=0;p<8;p++)for(unsigned c=0;c<132;c++)assert(ram[p][c]==0);
            display_on=1;
        }
    }
}
int main(void) {
    unsigned checks=0;memset(ram,0xaa,sizeof ram);
    assert(board_init()==0);checks++;
    assert(mode==0x70107 && baud==800);checks++;
    assert(dll==54 && dlm==0);checks++;
    assert(gpio_data&1U<<17);assert(gpio_dir&1U<<9);checks++;
    assert((gpio_dir&((1U<<10)|(1U<<11)|(1U<<18)))==((1U<<10)|(1U<<11)|(1U<<18)));checks++;
    assert(lcd_init()==1 && display_on);checks++;
    assert((gpio_data&((1U<<10)|(1U<<18)))==((1U<<10)|(1U<<18)));checks++;
    uint8_t frame[1024];for(unsigned i=0;i<sizeof frame;i++)frame[i]=(uint8_t)(i^(i>>8));
    unsigned before=bytes;assert(lcd_frame(frame));assert(bytes-before==1048);checks++;
    for(unsigned p=0;p<8;p++)for(unsigned c=0;c<132;c++){
        assert(ram[p][c]==(c<128?frame[128*p+c]:0));checks++;
    }
    assert(pulses>64);checks++; /* Poll RX between small chunks and reset waits. */
    assert(uart_read()==-1);checks++;
    rxbyte=65;assert(uart_read()==65);assert(uart_read()==-1);checks++;
    rxbyte=66;rxerror=1;assert(uart_read()==256);assert(uart_read()==-1);checks++;
    stuck=1;assert(lcd_frame(frame)==0);checks++; /* Bounded SPI fault path. */
    stop_ticks=1;assert(lcd_frame(frame)==0);checks++; /* Iteration bound if timer stalls. */
    assert(board_init()==10);checks++;
    printf("PASS board transport %u checks; UART1 divisors, mode0 500kHz request, clear-before-on,132-column DDRAM,128-column frames, RX pumping and SPI timeout\n",checks);
    return 0;
}
