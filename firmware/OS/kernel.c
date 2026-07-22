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
struct process *current_proc;
struct process *idle_proc;

struct sbiret sbi_call(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid) {
        register long a0 __asm__("a0") = arg0;
        register long a1 __asm__("a1") = arg1;
        register long a2 __asm__("a2") = arg2;
        register long a3 __asm__("a3") = arg3;
        register long a4 __asm__("a4") = arg4;
        register long a5 __asm__("a5") = arg5;
        register long a6 __asm__("a6") = fid;
        register long a7 __asm__("a7") = eid;

        __asm__ volatile (    "ecall\n"
                        : "=r"(a0), "=r"(a1)
                        : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6), "r"(a7)
                        : "memory");

        return (struct sbiret) {.error = a0, .value = a1};
}

int putchar(int c) {
        sbi_call(c, 0, 0, 0, 0, 0, 2, 0x4442434E);
}

void exit(void) {
        sbi_call(0, 0, 0, 0, 0, 0, 0, 0x53525354);
}

void putstr(size_t strlen, char *c) {
        sbi_call(strlen, (long)c, 0, 0, 0, 0, 0, 0x4442434E);
}

void handle_trap(struct trapframe *t, int cause) {
        uint32_t stval = READ_CSR(stval);
        uint32_t user_pc = READ_CSR(sepc);

        PANIC("unexpected trap scause=0x%08x, stval=0x%08x, sepc=0x%08x\n", cause, stval, user_pc);
}

paddr_t alloc_pages(u32 n) {
        static paddr_t next_paddr = (paddr_t)__free_ram;
        paddr_t paddr = next_paddr;
        next_paddr += n * PAGE_SIZE;

        if (next_paddr > (paddr_t)__free_ram_end)
                PANIC("Out of memory!");

        memset((void*)paddr, 0, n * PAGE_SIZE);
        return paddr;
}

struct process *create_process(u32 pc) {
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

void yield(void) {
        struct process *next = idle_proc;
        for (int i = 0; i < PROCS_MAX; i++) {
                struct process *proc = &procs[(current_proc->pid + i) % PROCS_MAX];
                if (proc->state == PROC_RUNNABLE && proc->pid > 0) {
                        next = proc;
                        break;
                }
        }

        // If no runnable processes other than current, return and continue running process
        if (next == current_proc)
                return;

        __asm__ volatile(
                        "csrw sscratch, %[sscratch]\n"
                        :: [sscratch] "r" ((u32) &next->stack[sizeof(next->stack)])
                        );

        // Context switch
        struct process *prev = current_proc;
        current_proc = next;
        switch_context(&prev->sp, &next->sp);
}

void delay(void) {
        for (int i = 0; i < 3000; i++)
                __asm__ volatile ("nop\n");
}

struct process *proc_a;
struct process *proc_b;

void proc_a_entry(void) {
        printf("Starting Process A\n");
        for (;;) {
                yield();
                putchar('A');
                delay();
        }
}

void proc_b_entry(void) {
        printf("Starting Process B\n");
        for (int i = 0; i < 20; i++) {
                yield();
                putchar('B');
                // if (i % 5 == 0)
                //         printf("Time: %x\n", READ_CSR(time));
                delay();
        }
        exit();
}

void kernel_main(void) {
        memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
        WRITE_CSR(stvec, (u32)kernel_entry);

        printf("Hello, World!\n");
        printf("Booted!\n");

        // Create idle process
        idle_proc = create_process((u32)NULL);
        idle_proc->pid = 0;
        current_proc = idle_proc;

        proc_a = create_process((u32)proc_a_entry);
        proc_b = create_process((u32)proc_b_entry);

        yield();

        PANIC("Switched to idle process");
        exit();
}

__attribute__ ((section (".text.boot")))
__attribute__ ((naked))
void boot(void) {
        __asm__ volatile (
                        "mv sp, %[stack_top]\n"
                        "j kernel_main\n"
                        :
                        : [stack_top] "r" (__stack_top)
                        );
}

