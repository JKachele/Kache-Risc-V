SECTIONS {
        . = 0x70000000;

        .text : {
                . = ALIGN(2);
                *startPipeline*.o (.text)
                *(.text*)
        }

        .data : {
                . = ALIGN(32);
                *(.data*)
                *(.sdata*)
                *(.rodata*)
                *(.srodata*)
                *(.bss*)
                *(.sbss*)

                *(COMMON)
                *(.eh_frame)  
                *(.eh_frame_hdr)
                *(.init_array*)         
                *(.gcc_except_table*)

                . = ALIGN(32);
                . += 64 * 1024; /* 128KB */
                __stack_top = .;
        }
}
