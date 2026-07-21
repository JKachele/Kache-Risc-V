.global main
.section .text
main:
        li t0, 0
        la t1, data
        lw t2, 0(t1)
        sw t2, 0(t0)
        lw t2, 4(t1)
        sw t2, 4(t0)
        nop
        li a0, 0
        li a1, 0
        nop
        lw a0, 0(t0)
        lw a1, 4(t0)
        ret

.section .data
data:
        .word 0x12345678
        .word 0x9abcdef0
