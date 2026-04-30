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
extern char __free_ram[];
extern char __free_ram_end[];

extern void kernel_entry(void);
extern void switch_context(u32 *prev_sp, u32 *next_sp);

struct process procs[PROCS_MAX];

struct sbiret sbiCall(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid) {
        register long a0 asm("a0") = arg0;
        register long a1 asm("a1") = arg1;
        register long a2 asm("a2") = arg2;
        register long a3 asm("a3") = arg3;
        register long a4 asm("a4") = arg4;
        register long a5 asm("a5") = arg5;
        register long a6 asm("a6") = fid;
        register long a7 asm("a7") = eid;

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

paddr_t allocPages(u32 n) {
        static paddr_t nextPaddr = (paddr_t)__free_ram;
        paddr_t paddr = nextPaddr;
        nextPaddr += n * PAGE_SIZE;

        if (nextPaddr > (paddr_t)__free_ram_end)
                PANIC("Out of memory!");

        memset((void*)paddr, 0, n * PAGE_SIZE);
        return paddr;
}

struct process *createProcess(u32 pc) {
        // Find unused process control block
        struct process *proc = NULL;
        int i;
        for (i = 0; i < PROCS_MAX; i++) {
                if (procs[i].state == PROC_UNUSED) {
                        proc = &procs[i];
                        break;
                }
        }

        if (!proc)
                PANIC("No available processes");

        // Initialize process registers to 0
        u32 *sp = (u32*)&proc->stack[sizeof(proc->stack)];
        for (int j = 0; j < 37; j++)
                *--sp = 0;
        *--sp = pc;

        // Initialize process fields
        proc->pid = i + 1;
        proc->state = PROC_RUNNABLE;
        proc->sp = (vaddr_t)sp;
        return proc;
}

void delay(void) {
        for (int i = 0; i < 3000; i++)
                asm volatile ("nop\n");
}

struct process *proc_a;
struct process *proc_b;

void procAEntry(void) {
        printf("Starting Process A\n");
        for (;;) {
                putchar('A');
                switch_context(&proc_a->sp, &proc_b->sp);
                delay();
        }
}

void procBEntry(void) {
        printf("Starting Process B\n");
        for (;;) {
                putchar('B');
                switch_context(&proc_b->sp, &proc_a->sp);
                delay();
        }
}

void kernel_main(void) {
        memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
        WRITE_CSR(stvec, (u32)kernel_entry);

        printf("Hello, World!\n");
        printf("Booted!\n");

        proc_a = createProcess((u32)procAEntry);
        proc_b = createProcess((u32)procBEntry);
        procAEntry();

        PANIC("Unreachable!");
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

