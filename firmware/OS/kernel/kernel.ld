ENTRY(_start)

SECTIONS {
        . = ALIGN(CONSTANT(MAXPAGESIZE));
        __kernel_base = .;

        .text.start : ALIGN(CONSTANT(MAXPAGESIZE)) {
                KEEP(*(.text.start));
        }

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
