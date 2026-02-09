/*************************************************
 *File----------test.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 27, 2026 13:51:30 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>
#include <math.h>

int main(int argc, char *argv[]) {
        unsigned int a;
        unsigned int b;
        unsigned int c;

        while (1) {
                scanf("%u", &a);
                scanf("%u", &b);
                scanf("%u", &c);
                float fa = *(float*)&a;
                float fb = *(float*)&b;
                float fc = *(float*)&c;

                float f = (fa < fb) ? fb : fa;

                unsigned int i = *(unsigned int*)&f;
                printf("%u\n", i);
                fflush(stdout);
        }

        return 0;
}

