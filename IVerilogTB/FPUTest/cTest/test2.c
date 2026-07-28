/*************************************************
 *File----------test2.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Jan 28, 2026 17:43:01 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>
#include <math.h>
#include <limits.h>

int main(int argc, char *argv[]) {
    printf("Hello, World!\n");

    double floats[] = {INFINITY, 14873529785728942080.0, -14873529785728942080.0, -INFINITY, NAN};

    for (int i = 0; i < 5; i++) {
            double d = floats[i];
            int j;
            if (!(d >= -2147483648 && d < 2147483647)) {
                    if (d < 0)
                            j = INT_MIN;
                    else
                            j = INT_MAX;
            } else {
                    j = (int)d;
            }
            printf("%d\n", j);
    }

    // int i1 = (int)inf;
    // int i2 = (int)large;
    // int i3 = (int)nlarge;
    // int i4 = (int)ninf;
    // int i5 = (int)nan;
    // printf("%d\n", i1);
    // printf("%d\n", i2);
    // printf("%d\n", i3);
    // printf("%d\n", i4);
    // printf("%d\n", i5);
    // printf("%d\n", INT_MAX);

    return 0;
}

