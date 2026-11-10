#ifndef DE25_MMIO_H
#define DE25_MMIO_H
#include <stdint.h>
#include <stddef.h>
#ifdef DE25_HOST_TEST
uint32_t de25_rd(uintptr_t);
void de25_wr(uintptr_t,uint32_t);
int de25_entry_contract(void);
void de25_timer_start(uint32_t);
#else
static inline uint32_t de25_rd(uintptr_t a) {return *(volatile uint32_t *)a;}
static inline void de25_wr(uintptr_t a,uint32_t v) {*(volatile uint32_t *)a=v;__asm__ volatile("dsb sy":::"memory");}
static inline int de25_entry_contract(void) {
    uint64_t el,sctlr;
    __asm__ volatile("mrs %0,CurrentEL":"=r"(el));
    if(el!=12)return 0; /* First-stage EL3 only; no speculative lower-EL MMIO. */
    __asm__ volatile("mrs %0,sctlr_el3":"=r"(sctlr));
    return !(sctlr&((1U<<0)|(1U<<2)|(1U<<12)));
}
static inline void de25_timer_start(uint32_t hz) {
    uint64_t value=hz;
    __asm__ volatile("msr cntfrq_el0,%0; isb"::"r"(value):"memory");
    de25_wr(0x10d01000,3); /* Official SoCFPGA global system counter enable. */
}
#endif
#define DE25_HANDOFF_WORDS (0x648U/4U)
uint32_t de25_validate_handoff(const uint32_t *);
uint32_t de25_cold_init(void);
#endif
