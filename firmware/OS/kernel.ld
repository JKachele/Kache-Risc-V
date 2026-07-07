ENTRY(_start)

SECTIONS {
        .text.bios : {
                . = ALIGN(2);
                KEEP(*(.text.bios));
        }

        .rodata.bios : {
                . = ALIGN(4);
                *(.rodata.bios*)
                *(.srodata.bios*)
        }

        .data.bios : {
                . = ALIGN(4);
                *(.data.bios*)
        }

        .sdata.bios : {
                . = ALIGN(4);
                *(.sdata.bios*)
        }

        .bss.bios : {
                . = ALIGN(4);
                __bss_bios = .;
                *(.bss.bios*)
                *(.sbss.bios*)
                __bss_bios_end = .;
        }
        . += 8 * 1024; /* 8KB */
        __stack_top_bios = .;

        .text : {
                . = ALIGN(2);
                *(.text .text.*);
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
                __bss = .;
                *(.bss*)
                *(.sbss*)
                __bss_end = .;
        }

        . += 8 * 1024; /* 8KB */
        __stack_top = .;

        . = ALIGN(4096);
        __free_ram = .;
        . += 128 * 1024; /*128KB */
        __free_ram_end = .;
}
