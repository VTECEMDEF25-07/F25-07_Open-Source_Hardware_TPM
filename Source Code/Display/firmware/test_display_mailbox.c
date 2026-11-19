/* Run the real display loop against an injected MMIO device. */
#include <assert.h>
#include <setjmp.h>
#include <stdio.h>
#include "lcd_status.h"

int lcd_demo_main(void);
static jmp_buf done;
static uint32_t regs[40], reset = 2, control, request, revision_retries;
static unsigned rendered, frames;
static const uintptr_t base = 0x20000000;

uint32_t de25_rd(uintptr_t address) {
    if (address == 0x10d1102c) return reset;
    if (address == 0x10d1205c) return control;
    if (address == 0x10d11014) return request;
    assert(address >= base && address < base + sizeof(regs) && !(address & 3));
    assert(!(reset & 2) && (control & 2));
    unsigned index = (address-base)/4;
    if (index == 8 && !revision_retries) {
        /* Simulate an operation replacing the result during the read. */
        revision_retries++;
        regs[1]++;
        regs[8] = 0x64636261;
        return 0xdeadbeef;
    }
    return regs[index];
}
void de25_wr(uintptr_t address, uint32_t value) {
    if (address == 0x10d11014) request = value;
    else if (address == 0x10d11018) assert(value == 512);
    else if (address == 0x10d1102c) reset = value;
    else { assert(address == 0x10d1205c); control = value; }
}

uint64_t ticks(void) { static uint64_t t; return ++t; }
uint32_t tick_hz(void) { return 1000; }
uint32_t board_init(void) { return 0; }
int lcd_init(void) { return 1; }
void render_status(uint8_t frame[1024], const struct snapshot *s, int stale) {
    (void)frame;
    assert(!stale && s->operation_id == 9 && frames == 2);
    rendered++;
}
void render_plaintext(uint8_t frame[1024], const struct plaintext_frame *t) {
    (void)frame;
    assert(t->operation_id == 8+frames && t->algorithm == (frames ? 4U : 2U));
    assert(t->length == 5 && t->bytes[0] == 'a' && t->bytes[1] == 'b');
    assert(t->bytes[2] == 'c' && t->bytes[3] == 'd' && t->bytes[4] == 'e');
    rendered++;
}
int lcd_frame(const uint8_t *frame) {
    (void)frame;
    assert(rendered == frames+1);
    frames++;
    if (frames == 3) longjmp(done, 1);
    regs[1]++; regs[6]++;
    regs[2] = regs[5] = 9;
    regs[3] = frames == 1 ? 0x405 : 0;
    return 1;
}

int main(void) {
    regs[0] = 0x444c4344;
    regs[1] = 1; regs[2] = regs[5] = 8; regs[3] = 0x205;
    regs[4] = 0x01020088; regs[6] = 3; regs[9] = 'e';
    if (!setjmp(done)) { lcd_demo_main(); assert(0); }
    assert(frames == 3 && revision_retries == 1);
    puts("PASS LCD mailbox: coherent AES/RSA plaintext, retry on replacement, clear on next operation");
    return 0;
}
