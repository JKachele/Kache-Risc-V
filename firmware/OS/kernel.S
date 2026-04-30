.global kernel_entry
.global switch_context
.section .text

.align 2
kernel_entry:
        # Get kernel stack of running process
        csrrw sp, sscratch, sp

        # Check if stack is 0, If it is, We trapped from the supervisor mode, can use current stack
        bnez sp, s_trap_start
        csrrw sp, sscratch, sp
s_trap_start:
        addi sp, sp, -4 * 95

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

        fsd ft0,  4 * 30(sp)
        fsd ft1,  4 * 32(sp)
        fsd ft2,  4 * 34(sp)
        fsd ft3,  4 * 36(sp)
        fsd ft4,  4 * 38(sp)
        fsd ft5,  4 * 40(sp)
        fsd ft6,  4 * 42(sp)
        fsd ft7,  4 * 44(sp)
        fsd fs0,  4 * 46(sp)
        fsd fs1,  4 * 48(sp)
        fsd fa0,  4 * 50(sp)
        fsd fa1,  4 * 52(sp)
        fsd fa2,  4 * 54(sp)
        fsd fa3,  4 * 56(sp)
        fsd fa4,  4 * 58(sp)
        fsd fa5,  4 * 60(sp)
        fsd fa6,  4 * 62(sp)
        fsd fa7,  4 * 64(sp)
        fsd fs2,  4 * 66(sp)
        fsd fs3,  4 * 68(sp)
        fsd fs4,  4 * 70(sp)
        fsd fs5,  4 * 72(sp)
        fsd fs6,  4 * 74(sp)
        fsd fs7,  4 * 76(sp)
        fsd fs8,  4 * 78(sp)
        fsd fs9,  4 * 80(sp)
        fsd fs10, 4 * 82(sp)
        fsd fs11, 4 * 84(sp)
        fsd ft8,  4 * 86(sp)
        fsd ft9,  4 * 88(sp)
        fsd ft10, 4 * 90(sp)
        fsd ft11, 4 * 92(sp)

        # Retrieve and save sp at time of execution
        csrr a0, sscratch
        sw a0, 4 * 94(sp)

        # Reset kernel stack
        # addi a0, sp, 4 * 31
        # csrw sscratch, a0

        mv a0, sp
        csrr a1, scause
        call handleTrap

        lw a0, 4 * 94(sp)
        csrw sscratch, a0

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

        fld ft0,  4 * 30(sp)
        fld ft1,  4 * 32(sp)
        fld ft2,  4 * 34(sp)
        fld ft3,  4 * 36(sp)
        fld ft4,  4 * 38(sp)
        fld ft5,  4 * 40(sp)
        fld ft6,  4 * 42(sp)
        fld ft7,  4 * 44(sp)
        fld fs0,  4 * 46(sp)
        fld fs1,  4 * 48(sp)
        fld fa0,  4 * 50(sp)
        fld fa1,  4 * 52(sp)
        fld fa2,  4 * 54(sp)
        fld fa3,  4 * 56(sp)
        fld fa4,  4 * 58(sp)
        fld fa5,  4 * 60(sp)
        fld fa6,  4 * 62(sp)
        fld fa7,  4 * 64(sp)
        fld fs2,  4 * 66(sp)
        fld fs3,  4 * 68(sp)
        fld fs4,  4 * 70(sp)
        fld fs5,  4 * 72(sp)
        fld fs6,  4 * 74(sp)
        fld fs7,  4 * 76(sp)
        fld fs8,  4 * 78(sp)
        fld fs9,  4 * 80(sp)
        fld fs10, 4 * 82(sp)
        fld fs11, 4 * 84(sp)
        fld ft8,  4 * 86(sp)
        fld ft9,  4 * 88(sp)
        fld ft10, 4 * 90(sp)
        fld ft11, 4 * 92(sp)

        addi sp, sp, 4 * 95
        csrrw sp, sscratch, sp

        # If trapped from supervisor mode, switch back to kernel stack
        bnez sp, s_trap_end
        csrrw sp, sscratch, sp
s_trap_end:
        sret

switch_context: # a0: prev_sp, a1: next_sp
        # Save callee-saved registers to old process stack
        addi    sp, sp, -4 * 38
        sw      ra,    4 * 0(sp)
        sw      s0,    4 * 1(sp)
        sw      s1,    4 * 2(sp)
        sw      s2,    4 * 3(sp)
        sw      s3,    4 * 4(sp)
        sw      s4,    4 * 5(sp)
        sw      s5,    4 * 6(sp)
        sw      s6,    4 * 7(sp)
        sw      s7,    4 * 8(sp)
        sw      s8,    4 * 9(sp)
        sw      s9,    4 * 10(sp)
        sw      s10,   4 * 11(sp)
        sw      s11,   4 * 12(sp)
        fsd     fs0,   4 * 14(sp)
        fsd     fs1,   4 * 16(sp)
        fsd     fs2,   4 * 18(sp)
        fsd     fs3,   4 * 20(sp)
        fsd     fs4,   4 * 22(sp)
        fsd     fs5,   4 * 24(sp)
        fsd     fs6,   4 * 26(sp)
        fsd     fs7,   4 * 28(sp)
        fsd     fs8,   4 * 30(sp)
        fsd     fs9,   4 * 32(sp)
        fsd     fs10,  4 * 34(sp)
        fsd     fs11,  4 * 36(sp)

        # Switch Stack Pointers
        sw      sp, (a0)        # *prev_sp = sp;
        lw      sp, (a1)        # sp = *next_sp;

        # Restore callee-saved registers from new process stack
        lw      ra,    4 * 0(sp)
        lw      s0,    4 * 1(sp)
        lw      s1,    4 * 2(sp)
        lw      s2,    4 * 3(sp)
        lw      s3,    4 * 4(sp)
        lw      s4,    4 * 5(sp)
        lw      s5,    4 * 6(sp)
        lw      s6,    4 * 7(sp)
        lw      s7,    4 * 8(sp)
        lw      s8,    4 * 9(sp)
        lw      s9,    4 * 10(sp)
        lw      s10,   4 * 11(sp)
        lw      s11,   4 * 12(sp)
        fld     fs0,   4 * 14(sp)
        fld     fs1,   4 * 16(sp)
        fld     fs2,   4 * 18(sp)
        fld     fs3,   4 * 20(sp)
        fld     fs4,   4 * 22(sp)
        fld     fs5,   4 * 24(sp)
        fld     fs6,   4 * 26(sp)
        fld     fs7,   4 * 28(sp)
        fld     fs8,   4 * 30(sp)
        fld     fs9,   4 * 32(sp)
        fld     fs10,  4 * 34(sp)
        fld     fs11,  4 * 36(sp)
        addi    sp, sp, 4 * 38
        ret
