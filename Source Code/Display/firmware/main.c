#include "lcd_status.h"
#include "de25_mmio.h"

volatile struct lcd_diagnostics lcd_diag;
volatile uint64_t lcd_exception[3];

enum {
    DISPLAY_BASE = 0x20000000,
    SIGNATURE = 0, REVISION, RESULT_ID, RESULT_INFO, STATUS, STATUS_ID, STATUS_SEQ,
    TEXT_WORDS = 8
};

static uint32_t display_word(unsigned index) {
    return de25_rd(DISPLAY_BASE + 4U * index);
}

/* The LCD driver also calls this while servicing SPI. Only the main loop polls
 * the mailbox, so a frame always uses a single, immutable local copy. */
void rx_pump(void) {}

/* Agilex 5 TRM reset-manager sequence, applied only to the lightweight bridge
 * from first-stage EL3. Secure MPU reads are permitted by the reset policy. */
static int settle_bridge(void) {
    uint64_t start = ticks();
    unsigned budget = 10000000;
    while (ticks() - start < tick_hz() / 1000U)
        if (!--budget) return 0;
    return 1;
}

static int enable_display_bridge(void) {
    const uintptr_t request = 0x10d11014, ack = 0x10d11018;
    const uintptr_t reset = 0x10d1102c, control = 0x10d1205c;
    const uint32_t flush = 1U << 9, lw = 1U << 1;
    if (de25_rd(reset) & lw) {
        de25_wr(request, de25_rd(request) | flush);
        if (!settle_bridge()) return 0;
        de25_wr(reset, de25_rd(reset) | lw);
        if (!settle_bridge()) return 0;
        de25_wr(request, de25_rd(request) & ~flush);
        if (!settle_bridge()) return 0;
        de25_wr(ack, flush);
        if (!settle_bridge()) return 0;
        de25_wr(reset, de25_rd(reset) & ~lw);
    }
    de25_wr(control, de25_rd(control) | lw);
    return !(de25_rd(reset) & lw);
}

int main(void) {
    static uint8_t frame[1024];
    uint32_t last_revision = 0, last_sequence = 0;
    int first = 1;
    lcd_diag.magic = 0x4c434430;
    lcd_diag.stage = 1;
    lcd_diag.error = board_init();
    if (lcd_diag.error) return 1;
    lcd_diag.stage = 2;
    if (!lcd_init()) { lcd_diag.error = 20; return 1; }
    if (!enable_display_bridge()) { lcd_diag.error = 23; return 1; }
    lcd_diag.stage = 3;
    if (display_word(SIGNATURE) != 0x444c4344) { lcd_diag.error = 24; return 1; }
    for (;;) {
        uint32_t seq = display_word(STATUS_SEQ);
        uint32_t rev = display_word(REVISION);
        if (!first && seq == last_sequence && rev == last_revision) continue;
        struct snapshot status = {display_word(STATUS), display_word(STATUS_ID), seq};
        struct plaintext_frame text;
        uint32_t info = display_word(RESULT_INFO);
        text.operation_id = display_word(RESULT_ID);
        text.sequence = seq;
        text.algorithm = (info >> 8) & 7;
        text.length = info & 255;
        int valid = (text.algorithm == 2 || text.algorithm == 4) && text.length <= sizeof(text.bytes);
        /* A rejected command can retain the last successful result. During
         * DONE, bind text to its actual result ID and algorithm. During idle,
         * the committed result bank holds the last successful operation. */
        uint32_t code = status.status_word & 15U;
        int captured = (status.status_word & 128U) != 0;
        int fault = (status.status_word & 64U) != 0 || code >= 9;
        if (fault && code < 9)
            status.status_word = (status.status_word & ~15U) | 9U;
        valid = valid && captured && !fault &&
                (code == 0 || (code == 8 && status.operation_id == text.operation_id &&
                               ((status.status_word >> 16) & 255U) == text.algorithm));
        if (valid) {
            for (unsigned i = 0; i < text.length; i += 4) {
                uint32_t word = display_word(TEXT_WORDS + i/4);
                for (unsigned j = 0; j < 4 && i+j < text.length; ++j)
                    text.bytes[i+j] = (uint8_t)(word >> (8*j));
            }
        }
        if (rev != display_word(REVISION) || seq != display_word(STATUS_SEQ)) continue;
        if (valid) render_plaintext(frame, &text);
        else render_status(frame, &status, 0);
        if (!lcd_frame(frame)) { lcd_diag.error = 21; return 1; }
        lcd_diag.frames++;
        lcd_diag.sequence = seq;
        last_sequence = seq;
        last_revision = rev;
        first = 0;
    }
}
