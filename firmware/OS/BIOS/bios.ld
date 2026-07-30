ENTRY(_start)

SECTIONS {
        .text(0x70000000) : {
                KEEP(*(.text.bios));
                *(.text*)
        }

        .rodata : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.rodata*)
                *(.srodata*)
        }

        .data : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.data*)
        }

        .sdata : ALIGN(CONSTANT(MAXPAGESIZE)) {
                __global_pointer$ = .;
                *(.sdata*)
        }

        .bss : ALIGN(CONSTANT(MAXPAGESIZE)) {
                __bss_bios = .;
                *(.bss*)
                *(.sbss*)
                __bss_bios_end = .;
        }
        . += 8 * 1024; /* 8KB */
        __stack_top_bios = .;
}
