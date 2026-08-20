.equ IO_UART_DATA, 0xF0000000
.equ IO_UART_CNTL, 0xF0000004

.global _putchar
.global _getchar
.global _charavail

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

_getchar:
        li t0, IO_UART_CNTL
        li t1, 1
        slli t1, t1, 8
_getLoop:
        lw t2, 0(t0)
        and t2, t2, t1
        beqz t2, _getLoop
        li t0, IO_UART_DATA
        lw a0, 0(t0)
        ret

_charavail:
        li t0, IO_UART_CNTL
        li t1, 1
        slli t1, t1, 8
        lw t2, 0(t0)
        and a0, t2, t1
        ret
