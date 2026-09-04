/*************************************************
 *File----------kernel.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 13:35:05 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "kernel.h"
#include "libs/printf.h"
#include "libs/string.h"
#include "common.h"

extern char __bss[];
extern char __bss_end[];
extern char __stack_top[];
extern char __free_ram[];
extern char __free_ram_end[];
extern char __kernel_base[];
extern char _binary_bin_app_bin_start[];
extern char _binary_bin_app_bin_size[];

extern void s_trap(void);
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

void putchar(int c) {
        sbi_call(c, 0, 0, 0, 0, 0, 2, 0x4442434E);
}

long getchar(void) {
        struct sbiret ret = sbi_call(0, 0, 0, 0, 0, 0, 0, 2);
        return ret.error;
}

void exit(void) {
        sbi_call(0, 0, 0, 0, 0, 0, 0, 0x53525354);
}

void putstr(size_t strlen, char *c) {
        sbi_call(strlen, (long)c, 0, 0, 0, 0, 0, 0x4442434E);
}

__attribute__ ((naked))
void user_entry(void) {
        __asm__ volatile (
                        "csrw sepc, %[sepc]\n"
                        "csrw sstatus, %[sstatus]\n"
                        "sret\n"
                        :: [sepc] "r" (USER_BASE), [sstatus] "r" (SSTATUS_SPIE)
                        );
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

void map_page(u32 *table1, u32 vaddr, paddr_t paddr, u32 flags) {
        if (!is_aligned(vaddr, PAGE_SIZE))
                PANIC("unaligned vaddr %x", vaddr);
        if (!is_aligned(paddr, PAGE_SIZE))
                PANIC("unaligned paddr %x", paddr);

        u32 vpn1 = (vaddr >> 22) & 0x3FF;
        if ((table1[vpn1] & PAGE_V) == 0) {
                // Creates 2nd level page table if it doesn't exist and maps to 1st level entry
                u32 pt_paddr = alloc_pages(1);
                table1[vpn1] = ((pt_paddr / PAGE_SIZE) << 10) | PAGE_V;
        }

        // Set up 2nd level page table entry to map the physical page
        u32 vpn0 = (vaddr >> 12) & 0x3FF;
        u32 *table0 = (u32*)((table1[vpn1] >> 10) * PAGE_SIZE);
        table0[vpn0] = ((paddr / PAGE_SIZE) << 10) | flags | PAGE_V;
}

struct process *create_process(const void *image, size_t image_size) {
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
        *--sp = (u32) user_entry;

        // Map kernel pages
        u32 *page_table = (u32*)alloc_pages(1);
        for (paddr_t paddr = (paddr_t)__kernel_base;
                        paddr < (paddr_t)__free_ram_end; paddr += PAGE_SIZE) {
                map_page(page_table, paddr, paddr, PAGE_R | PAGE_W | PAGE_X);
        }

        // Map user pages
        for (u32 off = 0; off < image_size; off += PAGE_SIZE) {
                paddr_t page = alloc_pages(1);

                // If the image is smaller than a page, copy only the remaining bytes
                size_t remaining = image_size - off;
                size_t copy_size = PAGE_SIZE <= remaining ? PAGE_SIZE : remaining;

                // Fill and map page
                memcpy((void*)page, image + off, copy_size);
                map_page(page_table, USER_BASE + off, page, PAGE_U | PAGE_R | PAGE_W | PAGE_X);
        }

        // Initialize process fields
        proc->pid = i + 1;
        proc->state = PROC_RUNNABLE;
        proc->sp = (vaddr_t)sp;
        proc->page_table = page_table;
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
                        "sfence.vma\n"
                        "csrw satp, %[satp]\n"
                        "sfence.vma\n"
                        "csrw sscratch, %[sscratch]\n"
                        :: [satp] "r" (SATP_SV32 | ((u32)next->page_table / PAGE_SIZE)),
                        [sscratch] "r" ((u32) &next->stack[sizeof(next->stack)])
                        );

        // Context switch
        struct process *prev = current_proc;
        current_proc = next;
        switch_context(&prev->sp, &next->sp);
}

void print_page_table(u32 *table, int level, u32 vpn) {
        for (int i = 0; i < 1024; i++) {
                if (table[i] & PAGE_V) {
                        if (level < 1) {
                                u32 *next_table = (u32*)((table[i] >> 10) * PAGE_SIZE);
                                print_page_table(next_table, level + 1, i);
                        } else {
                                u32 paddr = (table[i] >> 10) * PAGE_SIZE;
                                u32 vaddr = (vpn << 22) | (i << 12);
                                char r = (table[i] & PAGE_R) ? 'R' : '-';
                                char w = (table[i] & PAGE_W) ? 'W' : '-';
                                char x = (table[i] & PAGE_X) ? 'X' : '-';
                                char u = (table[i] & PAGE_U) ? 'U' : '-';
                                char g = (table[i] & PAGE_G) ? 'G' : '-';
                                char a = (table[i] & PAGE_A) ? 'A' : '-';
                                char d = (table[i] & PAGE_D) ? 'D' : '-';
                                printf("vaddr: 0x%08x -> paddr: 0x%08x [%c%c%c%c%c%c%c]\n",
                                                vaddr, paddr, r, w, x, u, g, a, d);
                        }
                }
        }
}

void kernel_main(void) {
        memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
        WRITE_CSR(stvec, (u32)s_trap);

        printf("Hello, World!\n");
        printf("Booted!\n");

        // Create idle process
        idle_proc = create_process(NULL, 0);
        idle_proc->pid = 0;
        current_proc = idle_proc;

        struct process *shell = create_process(_binary_bin_app_bin_start,
                        (size_t)_binary_bin_app_bin_size);
        // print_page_table(shell->page_table, 0, 0);

        yield();

        PANIC("Switched to idle process");
        exit();
}

void handle_syscall(struct trap_frame *f) {
        switch (f->a7) {
        case SYS_PUTCHAR:
                putchar(f->a0);
                break;
        case SYS_GETCHAR:
                for (;;) {
                        long ch = getchar();
                        if (ch >= 0) {
                                f->a0 = ch;
                                break;
                        }
                        yield();
                }
                break;
        case SYS_EXIT:
                printf("process %d exited\n", current_proc->pid);
                current_proc->state = PROC_EXITED;
                yield();
                PANIC("unreachable");
                break;
        default:
                PANIC("unexpected syscall a7=%x\n", f->a7);
                break;
        }
}

void handle_trap(struct trap_frame *f) {
        uint32_t scause = READ_CSR(scause);
        uint32_t stval = READ_CSR(stval);
        uint32_t user_pc = READ_CSR(sepc);
        uint32_t instret = READ_CSR(instret);

        switch (scause) {
        case SCAUSE_ECALL:
                handle_syscall(f);
                user_pc += 4;
                break;
        default:
                printf("Trap occurred at instret=%d\n", instret);
                PANIC("unexpected trap scause=0x%08x, stval=0x%08x, sepc=0x%08x\n",
                                scause, stval, user_pc);
                break;
        }
        WRITE_CSR(sepc, user_pc);
}

__attribute__ ((section (".text.start")))
__attribute__ ((naked))
void _start(void) {
        __asm__ volatile (
                        ".option push\n"
                        ".option norelax\n"
                        "mv sp, %[stack_top]\n"
                        "la gp, __global_pointer$\n"
                        "li tp, 0\n"
                        ".option pop\n"
                        "j kernel_main\n"
                        :
                        : [stack_top] "r" (__stack_top)
                        );
}

