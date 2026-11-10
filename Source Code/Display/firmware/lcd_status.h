#ifndef LCD_STATUS_H
#define LCD_STATUS_H
#include <stdint.h>
#include <stddef.h>
struct snapshot { uint32_t status_word, operation_id, sequence; };
struct lcd_diagnostics {uint32_t magic,stage,error,accepted,rejected,overruns,frames,sequence;};
extern volatile struct lcd_diagnostics lcd_diag;
int parse_snapshot(const char *, struct snapshot *);
void render_status(uint8_t frame[1024], const struct snapshot *, int stale);
uint32_t board_init(void);
uint64_t ticks(void);
uint32_t tick_hz(void);
int uart_read(void);
void uart_puts(const char *);
int lcd_init(void);
int lcd_frame(const uint8_t *);
void rx_pump(void);
int lcd_diag_begin(void);
void lcd_uart_diag(const char *,uint32_t,uint64_t,uint64_t,uint32_t);
void lcd_diag_quiet(void);
void lcd_exception_uart(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
#endif
