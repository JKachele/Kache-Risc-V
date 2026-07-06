.equ IO_UART_DATA, 0x90000000
.equ IO_UART_CNTL, 0x90000004

.global putchar
.text
putchar:
        li t0, IO_UART_CNTL
        li t1, 1
        slli t1, t1, 9
putLoop:
        lw t2, 0(t0)
        and t2, t2, t1
        bnez t2, putLoop
        li t0, IO_UART_DATA
        sw a0, 0(t0)
        ret
