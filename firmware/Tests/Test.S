.global main
.section .text
main:
        la t0, data
        li t1, 0x98765432
        sw t1, 0(t0)
        csrw 0x7c0, t0
        ret

.section .data
data:
        .word 0x12345678
        .word 0x9abcdef0
