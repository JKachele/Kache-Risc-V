.equ IO_BASE, 0x80000000
.equ IO_LEDS, 0x04

.global _start
.section .text
_start:
        li gp, IO_BASE
        la sp, __stack_top
        call main
        ebreak
