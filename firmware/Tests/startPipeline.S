.global _start
.section .text
_start:
        .option push
        .option norelax
        la sp, __stack_top
        la gp, __global_pointer$
        li tp, 0
        .option pop
        call main
        ebreak
