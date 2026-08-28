/*************************************************
 *File----------shell.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 18:48:36 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include "../user.h"

uint64_t rdcycle() {
        uint32_t low;
        uint32_t high;

        __asm__ volatile (
                "L%=:\n\t"
                "rdcycleh %0\n\t"
                "rdcycle  %1\n\t"
                "rdcycleh t0\n\t"
                "bne %0, t0, L%=\n"
                : "=r"(high), "=r"(low)
        );

        return ((uint64_t)high << 32) | low;
}

uint64_t rdinstret() {
        uint32_t low;
        uint32_t high;

        __asm__ volatile (
                "L%=:\n\t"
                "rdinstreth %0\n\t"
                "rdinstret  %1\n\t"
                "rdinstreth t0\n\t"
                "bne %0, t0, L%=\n"
                : "=r"(high), "=r"(low)
        );

        return ((uint64_t)high << 32) | low;
}

int main(void) {
        printf("Welcome to the Kache-Risc-V Shell!\n");

        // Loop prompt until exit command is received
        for (;;) {
prompt:
                printf("> ");
                char cmdline[128];
                for (int i = 0;; i++) {
                        char c = getchar();

                        if (c == 0x7f) {
                                if (i > 0) {
                                        i -= 2;
                                        printf("\b \b"); // Erase last character
                                }
                                continue;
                        } else if (c == '\r' || c == '\n') {
                                cmdline[i] = '\0';
                                printf("\r\n");
                                break;
                        }
                        putchar(c); // Echo input

                        if (i == (sizeof(cmdline) - 1)) {
                                printf("\nError: command too long\n");
                                goto prompt;
                        } else {
                                cmdline[i] = c;
                        }
                }

                if (strcmp(cmdline, "hello") == 0) {
                        printf("Hello world from shell!\n");
                } else if (strcmp(cmdline, "cycles") == 0) {
                        uint64_t cycles = rdcycle();
                        printf("Cycles: %llu\n", cycles);
                } else if (strcmp(cmdline, "instret") == 0) {
                        uint64_t instret = rdinstret();
                        printf("Instret: %llu\n", instret);
                } else if (strcmp(cmdline, "exit") == 0) {
                        printf("Exiting shell...\n");
                        exit();
                } else if (strcmp(cmdline, "help") == 0) {
                        printf("Available commands:\n");
                        printf("  help  - Show this help message\n");
                        printf("  hello - Show Hello message\n");
                        printf("  exit  - Exit the shell\n");
                } else {
                        printf("Unknown command: %s\n", cmdline);
                }
        }
}

