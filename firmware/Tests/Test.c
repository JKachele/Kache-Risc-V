/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>

unsigned int getMem(unsigned addr) {
        unsigned int data;
        asm volatile(
                        "lw %0, 0(%1)\n"
                        :"=r"(data)
                        :"r"(addr)
                    );
        return data;
}

int main(void) {
        printf("Hello, World!\n");
        for (int i = 0; i < 50; i++) {
                printf("%08x\n", getMem(0x80400000 + (i * 4)));
        }
}

