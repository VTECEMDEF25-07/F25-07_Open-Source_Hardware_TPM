/* Minimal freestanding current-EL startup. SDM must launch core Aff0=0,
 * MMU/caches disabled, little endian, IRQ/FIQ masked. No DDR required. */
.section .text.start,"ax"
.global _start
_start:
    msr daifset, #15
    mrs x0, mpidr_el1
    and x0, x0, #0xffffff
    cbnz x0, park
    msr spsel, #1
    ldr x0, =_stack_top
    mov sp, x0
    ldr x0, =vectors
    mrs x1, CurrentEL
    cmp x1, #12
    b.eq 1f
    cmp x1, #8
    b.eq 2f
    msr vbar_el1, x0
    b 3f
1:  msr vbar_el3, x0
    b 3f
2:  msr vbar_el2, x0
3:  isb
    ldr x0, =__bss_start
    ldr x1, =__bss_end
4:  cmp x0,x1
    b.hs 5f
    str xzr,[x0],#8
    b 4b
5:  bl main
park:
    wfe
    b park
exception:
    msr daifset, #15
    mrs x3, CurrentEL
    cmp x3, #12
    b.eq 6f
    cmp x3, #8
    b.eq 7f
    mrs x0, esr_el1
    mrs x1, elr_el1
    mrs x2, far_el1
    b 8f
6:  mrs x0, esr_el3
    mrs x1, elr_el3
    mrs x2, far_el3
    b 8f
7:  mrs x0, esr_el2
    mrs x1, elr_el2
    mrs x2, far_el2
8:  ldr x4, =lcd_exception
    stp x0,x1,[x4]
    str x2,[x4,#16]
    ldr x4, =lcd_diag
    mov x0, #0xeeee
    lsl x0,x0,#16
    orr x0,x0,x3
    str w0,[x4,#8]
    b park
.balign 2048
vectors:
.rept 16
    b exception
    .balign 128
.endr
