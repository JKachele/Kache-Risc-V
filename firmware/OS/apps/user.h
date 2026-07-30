/*************************************************
 *File----------user.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 18:46:29 EDT
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef USER_H
#define USER_H

#include "common.h"

__attribute__((noreturn)) void exit(void);
void putchar(char c);

#endif

