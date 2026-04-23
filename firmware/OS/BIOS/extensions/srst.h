/*************************************************
 *File----------srst.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:16:17 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef SRST_H
#define SRST_H

#include "../sbi.h"

struct sbiret srst(long arg0, long arg1, long arg2, long arg3, long arg4, long arg5, long fid);

#endif

