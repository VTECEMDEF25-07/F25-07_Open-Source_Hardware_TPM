OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { ROM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
         RAM (rw) : ORIGIN = 0x10000000, LENGTH = 16K }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) . = ALIGN(4); } > ROM
 .data : { __data_start = .; *(.data*) *(.sdata*) . = ALIGN(4); __data_end = .; } > RAM AT> ROM
 __data_load = LOADADDR(.data);
 .bss (NOLOAD) : { __bss_start = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(4); __bss_end = .; } > RAM
 ASSERT(__bss_end <= ORIGIN(RAM) + LENGTH(RAM) - 4096, "Reserve at least 4 KiB stack")
 /DISCARD/ : { *(.comment) *(.eh_frame*) }
}
