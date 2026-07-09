.equ IO_UART_DATA, 0xF0000000
.equ IO_UART_CNTL, 0xF0000004

.global _putchar
.text
_putchar:
        li t0, IO_UART_CNTL
        li t1, 1
        slli t1, t1, 9
_putLoop:
        lw t2, 0(t0)
        and t2, t2, t1
        bnez t2, _putLoop
        li t0, IO_UART_DATA
        sw a0, 0(t0)
        ret
