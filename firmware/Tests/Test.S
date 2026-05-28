.global main
.section .text
main:
        li t0, 0x10000000
        lw a0, 0(t0)
        li t0, 0x10000004
        lw a1, 0(t0)
        ret
