ENTRY(_start)

SECTIONS {
        . = 0xF0000000;

        .text : {
                . = ALIGN(2);
                KEEP(*(.text.bios));
                *(.text .text.*);
        }

        .data : {
                . = ALIGN(4);
                *(.data.bios*)
                *(.sdata.bios*)
                *(.rodata.bios*)
                *(.srodata.bios*)
                __bss_bios = .;
                *(.bss.bios*)
                *(.sbss.bios*)
                __bss_bios_end = .;

                . += 8 * 1024; /* 8KB */
                __stack_top_bios = .;

                . = ALIGN(4);
                *(.data*)
                *(.sdata*)
                *(.rodata*)
                *(.srodata*)
                __bss = .;
                *(.bss*)
                *(.sbss*)
                __bss_end = .;

                . += 8 * 1024; /* 8KB */
                __stack_top = .;

                . = ALIGN(4096);
                __free_ram = .;
                . += 128 * 1024; /*128KB */
                __free_ram_end = .;
        }
}
