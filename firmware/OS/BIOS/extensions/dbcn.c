/*************************************************
 *File----------dbcn.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:16:24 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "dbcn.h"

extern void _putchar(char c);
extern char _getchar();
extern char _charavail();

static struct sbiret sbi_debug_console_write(
                u32 num_bytes, char *base_addr_lo, char *base_addr_hi) {
        for (int i = 0; i < num_bytes; i++) {
                _putchar(base_addr_lo[i]);
        }
        return (struct sbiret){.error = SBI_SUCCESS, .uvalue = num_bytes};
}

// Read bytes from uart until line break, or null byte
// Will return 0 if no bytes available from uart
static struct sbiret sbi_debug_console_read(
                u32 num_bytes, char *base_addr_lo, char *base_addr_hi) {
        // Check if bytes available from uart
        if (!_charavail()) {
                return (struct sbiret){.error = SBI_SUCCESS, .uvalue = 0};
        }

        // Read bytes from uart
        for (int i = 0; i < num_bytes; i++) {
                char c = _getchar();
                base_addr_lo[i] = _getchar();
                if (c == '\n' || c == '\r' || c == '\0') {
                        return (struct sbiret){.error = SBI_SUCCESS, .uvalue = i};
                }
        }

        return (struct sbiret){.error = SBI_SUCCESS, .uvalue = num_bytes};
}

// EID #0x4442434E
struct sbiret dbcn(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid) {
        struct sbiret ret = {0};
        switch (fid) {
                case 0x0:
                        ret = sbi_debug_console_write(arg0, (char *)arg1, (char *)arg2);
                        break;
                case 0x1:
                        ret = sbi_debug_console_read(arg0, (char *)arg1, (char *)arg2);
                        break;
                case 0x2:
                        _putchar(arg0);
                        ret.error = SBI_SUCCESS;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}


