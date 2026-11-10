ENTRY(_start)
MEMORY { OCRAM (rwx) : ORIGIN = 0, LENGTH = 0x7f000 }
PHDRS { text PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) } > OCRAM :text
 .rodata : { *(.rodata*) } > OCRAM :text
 .data : { *(.data*) } > OCRAM :data
 .bss (NOLOAD) : { . = ALIGN(8); __bss_start = .; *(.bss*) *(COMMON) . = ALIGN(8); __bss_end = .; } > OCRAM :data
 .stack (NOLOAD) : { . = ALIGN(16); . += 16384; _stack_top = .; } > OCRAM :data
 /DISCARD/ : { *(.comment*) *(.note*) *(.eh_frame*) }
 ASSERT(_stack_top <= 0x7f000, "OCRAM image overlaps SDM handoff")
}
