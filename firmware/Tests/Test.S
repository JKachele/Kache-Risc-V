.global main
.section .text
main:
        li t0, 0x10000000
        lw a0, 0(t0)
        ret
