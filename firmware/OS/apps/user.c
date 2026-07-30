/*************************************************
 *File----------user.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 18:43:05 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include "user.h"

extern char __stack_top[];

__attribute__((noreturn)) void exit(void) {
        for (;;);
        __builtin_unreachable();
}

void putchar(char c) {
        // TODO
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

