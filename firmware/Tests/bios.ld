ENTRY(_start)

SECTIONS {
        .text.start (0x70000000) : {
                *startPipeline*.o (.text)
        }

        .text : ALIGN(CONSTANT(MAXPAGESIZE)) {
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
                *(.bss*)
                *(.sbss*)
        }

        . = ALIGN(CONSTANT(MAXPAGESIZE));
        . += 16 * 1024; /* 16KB */
        __stack_top = .;
}
