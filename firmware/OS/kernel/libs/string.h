/*************************************************
 *File----------string.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Thursday Sep 03, 2026 10:36:01 EDT
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef STRING_H
#define STRING_H

#include "../common.h"

void *memcpy(void *dst, const void *src, size_t n);
void *memset(void *buf, const char c, size_t n);
char *strcpy(char *dst, const char *src);
int strcmp(const char *s1, const char *s2);

#endif

