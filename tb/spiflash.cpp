/*************************************************
 *File----------spiflash.cpp
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Thursday May 14, 2026 20:38:29 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include <stdint.h>
#include "spiflash.h"

SPIFlash::SPIFlash(const int len, const bool debug) {
        m_memBytes = 24;
        m_memMask = (m_memBytes - 1);
        m_mem = new char[m_memBytes];
	m_state = SPIF_IDLE;
        m_last_sck = 1;
	memset(m_mem, 0x0ff, m_memBytes);
}

void SPIFlash::load(const unsigned addr, const char *fname) {
        FILE	*fp;
        size_t	len;
        int	nr = 0;

        if (addr >= m_memBytes)
                return;
        // If not given, then length is from the given address until the end
        // of the flash memory
        len = m_memBytes-addr;

        if (NULL != (fp = fopen(fname, "r"))) {
                nr = fread(&m_mem[addr], sizeof(char), len, fp);
                fclose(fp);
                if (nr == 0) {
                        fprintf(stderr, "SPI-FLASH: Could not read %s\n", fname);
                        perror("O/S Err:");
                }
        } else {
                fprintf(stderr, "SPI-FLASH: Could not open %s\n", fname);
                perror("O/S Err:");
        }

        for(unsigned i=nr+addr; i<m_memBytes; i++)
                m_mem[i] = 0x0ff;

        if (m_debug && addr == 0 && nr > 16) {
                fprintf(stderr, "FLASH LOAD: ");
                for(unsigned i=0; i<16; i++)
                        fprintf(stderr, "%02x ", m_mem[i]);
                fprintf(stderr, "\n");
        }
}

void SPIFlash::load(const uint32_t offset, const char *data, const uint32_t len) {
        uint32_t moff = (offset & (m_memMask));
        memcpy(&m_mem[moff], data, len);
}

int SPIFlash::operator()(const int csn, const int sck, const char dat) {
}

