/*************************************************
 *File----------shell.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 18:48:36 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include "../user.h"

int main(void) {
        printf("Welcome to the Kache-Risc-V Shell!\n");

        // Loop prompt until exit command is received
        for (;;) {
prompt:
                printf("> ");
                char cmdline[128];
                for (int i = 0;; i++) {
                        char c = getchar();
                        putchar(c); // Echo input

                        if (i == (sizeof(cmdline) - 1)) {
                                printf("\nError: command too long\n");
                                goto prompt;
                        } else if (c == '\r' || c == '\n') {
                                cmdline[i] = '\0';
                                printf("\n");
                                break;
                        } else {
                                cmdline[i] = c;
                        }
                }

                if (strcmp(cmdline, "hello") == 0) {
                        printf("Hello world from shell!\n");
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

