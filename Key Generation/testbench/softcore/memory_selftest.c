/*
 * Filename: memory_selftest.c
 * Authors: Project contributors; see Git history.
 * Date: 2026-10-13
 * General Description: Provides memory selftest support for the key-generation implementation and verification.
 * AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
 */

/* Test fixture only: exercise all CPU RAM byte lanes and halfword stores. */
#include <stdint.h>
int main(void)
{
    volatile uint32_t *word=(volatile uint32_t *)0x10001000u;
    volatile uint16_t *half=(volatile uint16_t *)word;
    volatile uint8_t *byte=(volatile uint8_t *)word;
    volatile uint32_t *report=(volatile uint32_t *)0x4000001cu;
    uint32_t failed=0;
    *word=0x11223344u;
    byte[0]=0xa1;byte[1]=0xb2;byte[2]=0xc3;byte[3]=0xd4;
    if(*word!=0xd4c3b2a1u) failed=4;
    half[0]=0x5566;half[1]=0x7788;
    if(*word!=0x77885566u) failed=4;
    if(byte[0]!=0x66 || byte[1]!=0x55 || byte[2]!=0x88 || byte[3]!=0x77) failed=4;
    if(half[0]!=0x5566 || half[1]!=0x7788) failed=4;
    *report=0xa5000000u|failed;
    for(;;) { __asm__ volatile("nop"); }
}
