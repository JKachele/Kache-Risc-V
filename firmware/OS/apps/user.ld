ENTRY(_start)

SECTIONS {
        . = 0x1000000;

        .text : ALIGN(CONSTANT(MAXPAGESIZE)) {
                KEEP(*(.text.start));
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
                *(.bss*)
                *(.sbss*)

                . += 8 * 1024; /* 8KB */
                __stack_top = .;

                ASSERT(. < 0x1800000, "too large executable");
        }
}
