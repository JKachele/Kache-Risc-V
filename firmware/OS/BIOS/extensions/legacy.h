/*************************************************
 *File----------legacy.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:19:21 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef LEGACY_H
#define LEGACY_H

#include "../sbi.h"

long sbi_console_putchar(int ch);
void sbi_shutdown(void);

#endif

