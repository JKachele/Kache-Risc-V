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
        unsigned long a;
        unsigned long b;
        unsigned long c;

        while (1) {
                scanf("%lu", &a);
                scanf("%lu", &b);
                scanf("%lu", &c);
                double fa = *(double*)&a;
                double fb = *(double*)&b;
                double fc = *(double*)&c;

                double f = sqrt(fa);

                unsigned long i = *(unsigned long*)&f;
                printf("%lu\n", i);
                fflush(stdout);
        }

        return 0;
}

