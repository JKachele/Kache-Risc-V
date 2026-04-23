/*************************************************
 *File----------legacy.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:19:23 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "legacy.h"

extern void _putchar(char c);

// EID #0x01
long sbi_console_putchar(int ch) {
        _putchar(ch);
        return SBI_SUCCESS;
}

// EID #0x08
void sbi_shutdown(void) {
        asm volatile ("ebreak\n");
}


