/*************************************************
 *File----------kernel.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 14:47:25 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef KERNEL_H
#define KERNEL_H

#include "common.h"

#define PANIC(fmt, ...)                                                                 \
        do {                                                                            \
                printf("PANIC: %s:%d: " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);   \
                asm volatile("ebreak\n");                                               \
                while (1) {}                                                            \
        } while (0)

#define READ_CSR(reg)                                                                   \
        ({                                                                              \
         unsigned long __tmp;                                                           \
         asm volatile("csrr %0, " #reg : "=r"(__tmp));                                  \
         __tmp;                                                                         \
         })

#define WRITE_CSR(reg, value)                                                           \
        do {                                                                            \
                uint32_t __tmp = (value);                                               \
                asm volatile("csrw " #reg ", %0" ::"r"(__tmp));                         \
        } while (0)

#define PROCS_MAX 8
#define PROC_UNUSED   0
#define PROC_RUNNABLE 1


struct process {
        int pid;        // Process ID
        int state;      // Process state (PROC_UNUSED or PROC_RUNNING)
        vaddr_t sp;     // Stack pointer
        u8 stack[8192]; // Kernel stack
};

struct sbiret {
        long error;
        long value;
};

struct trap_frame {
    uint32_t ra;
    uint32_t gp;
    uint32_t tp;
    uint32_t t0;
    uint32_t t1;
    uint32_t t2;
    uint32_t t3;
    uint32_t t4;
    uint32_t t5;
    uint32_t t6;
    uint32_t a0;
    uint32_t a1;
    uint32_t a2;
    uint32_t a3;
    uint32_t a4;
    uint32_t a5;
    uint32_t a6;
    uint32_t a7;
    uint32_t s0;
    uint32_t s1;
    uint32_t s2;
    uint32_t s3;
    uint32_t s4;
    uint32_t s5;
    uint32_t s6;
    uint32_t s7;
    uint32_t s8;
    uint32_t s9;
    uint32_t s10;
    uint32_t s11;
    uint32_t sp;
} __attribute__((packed));

#endif

