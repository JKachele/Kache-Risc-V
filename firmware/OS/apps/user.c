/*************************************************
 *File----------user.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 18:43:05 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include "user.h"
#include "../kernel/common.h"

extern char __stack_top[];

int syscall(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long arg6, long sysno) {
        register long a0 __asm__("a0") = arg0;
        register long a1 __asm__("a1") = arg1;
        register long a2 __asm__("a2") = arg2;
        register long a3 __asm__("a3") = arg3;
        register long a4 __asm__("a4") = arg4;
        register long a5 __asm__("a5") = arg5;
        register long a6 __asm__("a6") = arg6;
        register long a7 __asm__("a7") = sysno;

        __asm__ volatile (    "ecall\n"
                        : "=r"(a0)
                        : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6), "r"(a7)
                        : "memory");

        return a0;
}

void exit(void) {
        syscall(0, 0, 0, 0, 0, 0, 0, SYS_EXIT);
        for (;;); // Just in case!
}

void putchar(char c) {
        syscall((long)c, 0, 0, 0, 0, 0, 0, SYS_PUTCHAR);
}

int getchar(void) {
        return syscall(0, 0, 0, 0, 0, 0, 0, SYS_GETCHAR);
}

__attribute__ ((section (".text.start")))
__attribute__ ((naked))
void _start(void) {
        __asm__ volatile (
                        "mv sp, %[stack_top]\n"
                        "call main\n"
                        "call exit\n"
                        :: [stack_top] "r" (__stack_top)
                        );
}

