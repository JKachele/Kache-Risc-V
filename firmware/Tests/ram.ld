SECTIONS {
        . = 0xF0000000;

        .text : {
                . = ALIGN(2);
                *startPipeline*.o (.text)
                *(.text*)
        }

        .data : {
                . = ALIGN(4);
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
        }
}
