.equ IO_BASE, 0x20000000
.equ IO_LEDS, 0x04

.global _start
.section .text.bios
_start:
        li gp, IO_BASE
        la sp, __stack_top_bios

machine:
        # Set machine mode pointer to boot function
        la      t0, boot
        csrw    mepc, t0

        # Set Machine mode Trap vector to m_trap
        la      t1, m_trap
        csrw    mtvec, t1

        # Set previous privilege mode to Supervisor mode
        li      t2, 0x1800
        csrc    mstatus, t2
        li      t3, 0x800
        csrs    mstatus, t3

        # Set user mode exceprions to be handled by the supervisor trap handler
        li      t4, 0x104
        csrs    medeleg, t4

        # Save the current stack pointer in the scratch reister
        csrw    mscratch, sp

        # Return to boot function in s-mode
        mret

m_trap:
        # Get Machine Mode stack
        csrrw sp, mscratch, sp

        addi sp, sp, -4 * 63

        sw ra,    4 * 0(sp)
        sw gp,    4 * 1(sp)
        sw tp,    4 * 2(sp)
        sw t0,    4 * 3(sp)
        sw t1,    4 * 4(sp)
        sw t2,    4 * 5(sp)
        sw t3,    4 * 6(sp)
        sw t4,    4 * 7(sp)
        sw t5,    4 * 8(sp)
        sw t6,    4 * 9(sp)
        sw a0,    4 * 10(sp)
        sw a1,    4 * 11(sp)
        sw a2,    4 * 12(sp)
        sw a3,    4 * 13(sp)
        sw a4,    4 * 14(sp)
        sw a5,    4 * 15(sp)
        sw a6,    4 * 16(sp)
        sw a7,    4 * 17(sp)
        sw s0,    4 * 18(sp)
        sw s1,    4 * 19(sp)
        sw s2,    4 * 20(sp)
        sw s3,    4 * 21(sp)
        sw s4,    4 * 22(sp)
        sw s5,    4 * 23(sp)
        sw s6,    4 * 24(sp)
        sw s7,    4 * 25(sp)
        sw s8,    4 * 26(sp)
        sw s9,    4 * 27(sp)
        sw s10,   4 * 28(sp)
        sw s11,   4 * 29(sp)

        fsw ft0,  4 * 30(sp)
        fsw ft1,  4 * 31(sp)
        fsw ft2,  4 * 32(sp)
        fsw ft3,  4 * 33(sp)
        fsw ft4,  4 * 34(sp)
        fsw ft5,  4 * 35(sp)
        fsw ft6,  4 * 36(sp)
        fsw ft7,  4 * 37(sp)
        fsw fs0,  4 * 38(sp)
        fsw fs1,  4 * 39(sp)
        fsw fa0,  4 * 40(sp)
        fsw fa1,  4 * 41(sp)
        fsw fa2,  4 * 42(sp)
        fsw fa3,  4 * 43(sp)
        fsw fa4,  4 * 44(sp)
        fsw fa5,  4 * 45(sp)
        fsw fa6,  4 * 46(sp)
        fsw fa7,  4 * 47(sp)
        fsw fs2,  4 * 48(sp)
        fsw fs3,  4 * 49(sp)
        fsw fs4,  4 * 50(sp)
        fsw fs5,  4 * 51(sp)
        fsw fs6,  4 * 52(sp)
        fsw fs7,  4 * 53(sp)
        fsw fs8,  4 * 54(sp)
        fsw fs9,  4 * 55(sp)
        fsw fs10, 4 * 56(sp)
        fsw fs11, 4 * 57(sp)
        fsw ft8,  4 * 58(sp)
        fsw ft9,  4 * 59(sp)
        fsw ft10, 4 * 60(sp)
        fsw ft11, 4 * 61(sp)

        # Retrieve and save sp at time of execution
        csrr a0, mscratch
        sw a0, 4 * 62(sp)

        # Reset Machine stack
        addi a0, sp, 4 * 63
        csrw mscratch, a0

        mv a0, sp
        csrr a1, mcause
        call mtrap_handler

        lw ra,    4 * 0(sp)
        lw gp,    4 * 1(sp)
        lw tp,    4 * 2(sp)
        lw t0,    4 * 3(sp)
        lw t1,    4 * 4(sp)
        lw t2,    4 * 5(sp)
        lw t3,    4 * 6(sp)
        lw t4,    4 * 7(sp)
        lw t5,    4 * 8(sp)
        lw t6,    4 * 9(sp)
        lw a0,    4 * 10(sp)
        lw a1,    4 * 11(sp)
        lw a2,    4 * 12(sp)
        lw a3,    4 * 13(sp)
        lw a4,    4 * 14(sp)
        lw a5,    4 * 15(sp)
        lw a6,    4 * 16(sp)
        lw a7,    4 * 17(sp)
        lw s0,    4 * 18(sp)
        lw s1,    4 * 19(sp)
        lw s2,    4 * 20(sp)
        lw s3,    4 * 21(sp)
        lw s4,    4 * 22(sp)
        lw s5,    4 * 23(sp)
        lw s6,    4 * 24(sp)
        lw s7,    4 * 25(sp)
        lw s8,    4 * 26(sp)
        lw s9,    4 * 27(sp)
        lw s10,   4 * 28(sp)
        lw s11,   4 * 29(sp)

        flw ft0,  4 * 30(sp)
        flw ft1,  4 * 31(sp)
        flw ft2,  4 * 32(sp)
        flw ft3,  4 * 33(sp)
        flw ft4,  4 * 34(sp)
        flw ft5,  4 * 35(sp)
        flw ft6,  4 * 36(sp)
        flw ft7,  4 * 37(sp)
        flw fs0,  4 * 38(sp)
        flw fs1,  4 * 39(sp)
        flw fa0,  4 * 40(sp)
        flw fa1,  4 * 41(sp)
        flw fa2,  4 * 42(sp)
        flw fa3,  4 * 43(sp)
        flw fa4,  4 * 44(sp)
        flw fa5,  4 * 45(sp)
        flw fa6,  4 * 46(sp)
        flw fa7,  4 * 47(sp)
        flw fs2,  4 * 48(sp)
        flw fs3,  4 * 49(sp)
        flw fs4,  4 * 50(sp)
        flw fs5,  4 * 51(sp)
        flw fs6,  4 * 52(sp)
        flw fs7,  4 * 53(sp)
        flw fs8,  4 * 54(sp)
        flw fs9,  4 * 55(sp)
        flw fs10, 4 * 56(sp)
        flw fs11, 4 * 57(sp)
        flw ft8,  4 * 58(sp)
        flw ft9,  4 * 59(sp)
        flw ft10, 4 * 60(sp)
        flw ft11, 4 * 61(sp)

        lw sp,    4 * 62(sp)

        mret
