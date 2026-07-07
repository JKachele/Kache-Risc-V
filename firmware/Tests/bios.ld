SECTIONS {
        . = 0x70000000;

        .text : {
                . = ALIGN(2);
                *startPipeline*.o (.text)
                *(.text*)
        }

        .rodata : {
                . = ALIGN(4);
                *(.rodata*)
                *(.srodata*)
        }

        .data : {
                . = ALIGN(4);
                *(.data*)
        }

        .sdata : {
                . = ALIGN(4);
                __global_pointer$ = .;
                *(.sdata*)
        }

        .bss : {
                . = ALIGN(4);
                *(.bss*)
                *(.sbss*)
        }

        . = ALIGN(32);
        . += 16 * 1024; /* 16KB */
        __stack_top = .;
}
