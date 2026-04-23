/*************************************************
 *File----------common.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Jan 14, 2026 16:48:46 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef COMMON_H
#define COMMON_H

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

typedef uint32_t size_t;
typedef int ptrdiff_t;
typedef long long intmax_t;
typedef uint32_t uintptr_t;
typedef uint32_t paddr_t;
typedef uint32_t vaddr_t;

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;

typedef _Bool bool;

#define true 1
#define false 0
#define NULL ((void*)0)
#define va_list  __builtin_va_list
#define va_start __builtin_va_start
#define va_end   __builtin_va_end
#define va_arg   __builtin_va_arg
#define DBL_MAX	1.7976931348623157e+308
#define DBL_MIN	2.2250738585072014e-308

void *memset(void *buf, char c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
char *strcpy(char *dst, const char *src);
int strcmp(const char *s1, const char *s2);

#endif

