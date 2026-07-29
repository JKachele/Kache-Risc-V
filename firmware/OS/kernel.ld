ENTRY(_start)

SECTIONS {
        .text.bios : ALIGN(CONSTANT(MAXPAGESIZE)) {
                KEEP(*(.text.bios));
        }

        .rodata.bios : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.rodata.bios*)
                *(.srodata.bios*)
        }

        .data.bios : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.data.bios*)
        }

        .sdata.bios : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.sdata.bios*)
        }

        .bss.bios : ALIGN(CONSTANT(MAXPAGESIZE)) {
                __bss_bios = .;
                *(.bss.bios*)
                *(.sbss.bios*)
                __bss_bios_end = .;
        }
        . += 8 * 1024; /* 8KB */
        __stack_top_bios = .;

        . = ALIGN(CONSTANT(MAXPAGESIZE));
        __kernel_base = .;

        .text : ALIGN(CONSTANT(MAXPAGESIZE)) {
                *(.text .text.*);
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
                __bss = .;
                *(.bss*)
                *(.sbss*)
                __bss_end = .;
        }

        . += 8 * 1024; /* 8KB */
        __stack_top = .;

        . = ALIGN(CONSTANT(MAXPAGESIZE));
        __free_ram = .;
        . += 128 * 1024; /*128KB */
        __free_ram_end = .;
}
