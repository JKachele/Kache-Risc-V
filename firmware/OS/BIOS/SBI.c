/*************************************************
 *File----------SBI.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 14:04:04 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "sbi.h"
#include "extensions/legacy.h"
#include "extensions/dbcn.h"
#include "extensions/srst.h"

typedef unsigned char bool;
#define false 0
#define true  1

extern void _putchar(char c);

void print(const char *str) {
        while (*str) {
                _putchar(*str);
                str++;
        }
        return;
}

void print_int(int num) {
        for ( int i = 7; i >= 0; i-- ) {
                char c = (num >> (i * 4)) & 0xF;
                if (c < 10) {
                        _putchar(c + '0');
                } else {
                        _putchar(c - 10 + 'A');
                }
        }
}

void timer_handler(void) {
        print("\nTimer Interupt!\n");
        __asm__ volatile(
                        "li     t0, 0x80000008\n"
                        "lw     a0, 0(t0)\n"
                        "lw     a1, 4(t0)\n"
                        "li     t1, 0x8000\n"
                        "add    a0, a0, t1\n"
                        "sltu   t2, a0, t1\n"
                        "add    a1, a1, t2\n"
                        "li     t1, -1\n"
                        "sw     t1, 0(t0)\n"
                        "sw     a1, 4(t0)\n"
                        "sw     a0, 0(t0)\n"
                        ::: "a0", "a1", "t0", "t1", "t2", "memory"
                        );
        return;
}

struct sbiret sbi_handler(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid) {
        struct sbiret ret = {0};
        switch (eid) {
                case 0x01:
                        ret.error = sbi_console_putchar((char)arg0);
                        break;
                case 0x02:
                        ret.error = sbi_console_getchar();
                        break;
                case 0x08:
                        sbi_shutdown();
                        break;
                case 0x53525354:
                        ret = srst(arg0, arg1, arg2, arg3, arg4, arg5, fid);
                        break;
                case 0x4442434E:
                        ret = dbcn(arg0, arg1, arg2, arg3, arg4, arg5, fid);
                        break;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}

unsigned int mtrap_handler(struct trap_frame *f, int cause, unsigned int mepc) {
        struct sbiret ret;
        switch (cause) {
                case 0x02: // Illegal Instruction
                        print("\nIllegal Instruction at 0x");
                        print_int(mepc);
                        print("\n");
                        sbi_shutdown();
                        break;
                case 0x09: // S-Mode ecall
                case 0x0A: // M-Mode ecall
                        ret = sbi_handler(f->a0, f->a1, f->a2, f->a3, f->a4, f->a5, f->a6, f->a7);
                        f->a0 = ret.error;
                        f->a1 = ret.uvalue;
                        mepc += 4;
                        break;
                case 0x8007: // M-Mode timer interupt
                        timer_handler();
                        break;
                default:
                        print("\nUnexpected Trap!\n");
                        sbi_shutdown();
                        break;
        }
        return mepc;
}

