/* Run the real display loop against an injected MMIO device. */
#include <assert.h>
#include <setjmp.h>
#include <stdio.h>
#include "lcd_status.h"

int lcd_demo_main(void);
static jmp_buf done;
static uint32_t regs[40], reset = 2, control, request, revision_retries;
static unsigned rendered, frames, pattern_sent;
static const uintptr_t base = 0x20000000;
static const uintptr_t ccu_address[] = {0x1c0003c0, 0x1c000444, 0x1c000448, 0x1c000440};
static const uint32_t ccu_expected[] = {0xffffffe3, 0x20000, 0xffffff00, 0xff1fc1e6};
static uint32_t ccu_words[] = {~0U, ~0U, ~0U, ~0U};
static unsigned ccu_written;

uint32_t de25_rd(uintptr_t address) {
    for (unsigned i = 0; i < 4; ++i)
        if (address == ccu_address[i]) return ccu_words[i];
    if (address == 0x10d1102c) return reset;
    if (address == 0x10d1205c) return control;
    if (address == 0x10d11014) return request;
    assert(address >= base && address < base + sizeof(regs) && !(address & 3));
    assert(pattern_sent && ccu_written == 4 && !(reset & 2) && (control & 2));
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
    if (ccu_written < 4 && address == ccu_address[ccu_written]) {
        assert(pattern_sent && value == ccu_expected[ccu_written]);
        ccu_words[ccu_written++] = value;
        return;
    }
    if (address == 0x10d11014) request = value;
    else if (address == 0x10d11018) assert(value == 512);
    else if (address == 0x10d1102c) reset = value;
    else { assert(address == 0x10d1205c); control = value; }
}

uint64_t ticks(void) { static uint64_t t; return ++t; }
uint32_t tick_hz(void) { return 1000; }
uint32_t board_init(void) { return 0; }
int lcd_init(void) { return 1; }
int lcd_diag_begin(void) { return 1; }
void lcd_diag_quiet(void) {}
void uart_puts(const char *s) { (void)s; }
void render_status(uint8_t frame[1024], const struct snapshot *s, int stale) {
    (void)frame;
    if (!s) { assert(!pattern_sent && !rendered); return; }
    assert(!stale);
    switch (frames) {
        case 3: assert((s->status_word & 15U) == 9); break;
        case 4: assert((s->status_word & 15U) == 9); break;
        case 5: assert(s->operation_id == 12); break;
        case 6: assert(((s->status_word >> 16) & 255U) == 2); break;
        case 7: assert((s->status_word & 15U) == 7); break;
        case 8: assert(!regs[3]); break;
        default: assert(0);
    }
    rendered++;
}
void render_plaintext(uint8_t frame[1024], const struct plaintext_frame *t) {
    (void)frame;
    assert(frames <= 2);
    assert(t->operation_id == (frames ? 9U : 8U) && t->algorithm == (frames ? 4U : 2U));
    assert(t->length == 5 && t->bytes[0] == 'a' && t->bytes[1] == 'b');
    assert(t->bytes[2] == 'c' && t->bytes[3] == 'd' && t->bytes[4] == 'e');
    rendered++;
}
int lcd_frame(const uint8_t *frame) {
    (void)frame;
    if (!pattern_sent) {
        for (unsigned i=0; i<128; i++) {
            assert(frame[i] == ((i & 8) ? 255 : 0));
            assert(frame[7*128+i] == ((i & 8) ? 0 : 255));
        }
        pattern_sent=1;
        return 1;
    }
    assert(rendered == frames+1);
    frames++;
    regs[6]++;
    switch (frames) {
        case 1: regs[1]++; regs[2] = regs[5] = 9; regs[3] = 0x405; regs[4] = 0x01040088; break;
        case 2: regs[5] = 11; regs[4] = 0x01000080; break; /* Unrelated idle */
        case 3: regs[4] = 0x01ff00c9; break;                /* Recovery */
        case 4: regs[4] = 0x010000c0; break;                /* Error bit */
        case 5: regs[4] = 0x01040088; regs[5] = 12; break;  /* Different operation */
        case 6: regs[4] = 0x01020088; regs[5] = 9; break;   /* Different algorithm */
        case 7: regs[4] = 0x01000087; break;                /* In progress */
        case 8: regs[3] = 0; regs[1]++; regs[4] = 0x01000080; break;
        case 9: longjmp(done, 1);
    }
    return 1;
}

int main(void) {
    regs[0] = 0x444c4344;
    regs[1] = 1; regs[2] = regs[5] = 8; regs[3] = 0x205;
    regs[4] = 0x01020088; regs[6] = 3; regs[9] = 'e';
    if (!setjmp(done)) { lcd_demo_main(); assert(0); }
    assert(frames == 9 && revision_retries == 1);
    puts("PASS LCD mailbox: coherent AES/RSA, stale-result/error priority, idle persistence, retry on replacement");
    return 0;
}
