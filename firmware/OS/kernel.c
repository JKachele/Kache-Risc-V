/*************************************************
 *File----------kernel.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 13:35:05 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "kernel.h"
#include "libs/printf.h"
#include "common.h"

extern char __bss[];
extern char __bss_end[];
extern char __stack_top[];

extern void kernel_entry(void);

struct sbiret sbiCall(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid) {
        register long a0 __asm__("a0") = arg0;
        register long a1 __asm__("a1") = arg1;
        register long a2 __asm__("a2") = arg2;
        register long a3 __asm__("a3") = arg3;
        register long a4 __asm__("a4") = arg4;
        register long a5 __asm__("a5") = arg5;
        register long a6 __asm__("a6") = fid;
        register long a7 __asm__("a7") = eid;

        asm volatile (    "ecall\n"
                        : "=r"(a0), "=r"(a1)
                        : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6), "r"(a7)
                        : "memory");

        return (struct sbiret) {.error = a0, .value = a1};
}

int putchar(int c) {
        sbiCall(c, 0, 0, 0, 0, 0, 2, 0x4442434E);
}

void exit(void) {
        sbiCall(0, 0, 0, 0, 0, 0, 0, 0x53525354);
}

void putstr(size_t strLen, char *c) {
        sbiCall(strLen, (long)c, 0, 0, 0, 0, 0, 0x4442434E);
}

void handleTrap(struct trapframe *t, int cause) {
        uint32_t stval = READ_CSR(stval);
        uint32_t user_pc = READ_CSR(sepc);

        PANIC("unexpected trap scause=0x%08x, stval=0x%08x, sepc=0x%08x\n", cause, stval, user_pc);
}

void kernel_main(void) {
        memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
        WRITE_CSR(stvec, (u32)kernel_entry);

        printf("Hello, World!\n");
        // asm volatile ("unimp\n");

        printf("Booted!\n");

        exit();
}

__attribute__ ((section (".text.boot")))
__attribute__ ((naked))
void boot(void) {
        asm volatile (
                        "mv sp, %[stack_top]\n"
                        "j kernel_main\n"
                        :
                        : [stack_top] "r" (__stack_top)
                        );
}

