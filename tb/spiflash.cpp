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
        m_memBytes = (1<<len);
        m_memMask = (m_memBytes - 1);
        m_mem = new unsigned char[m_memBytes];
	m_state = SPIF_IDLE;
	m_mode = SPIF_MODE_READ;
        m_last_sck = 1;
        m_debug = debug;
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

void SPIFlash::print(const unsigned addr, const uint32_t len) {
        for (int i = 0; i < len; i++) {
                printf("%02x ", m_mem[addr+i]);
                if (i % 8 == 7)
                        printf("\n");
        }
}

unsigned int SPIFlash::operator()(const int csn, const int sck, const char dat) {
        // Chip is not selected
        if (csn) {
                m_last_sck = 1;
                m_count = 0;
                m_state = SPIF_IDLE;
                return dat;
        }


        if (sck == 1 && m_last_sck == 0) {      // Rising Edge - Read cmd and address
                if (m_state == SPIF_IDLE) {
                        m_state = SPIF_READ_CMD;
                        m_command = 0;
                        m_address = 0;
                }
                if (m_state == SPIF_READ_CMD) {
                        m_command <<= 1;
                        m_command |= dat;
                        if (m_count == 7) {
                                m_state = SPIF_READ_ADDR;
                                switch (m_command) {
                                        case 0x03: m_mode = SPIF_MODE_READ; break;
                                        case 0x3B: m_mode = SPIF_MODE_DOR; break;
                                        case 0x6B: m_mode = SPIF_MODE_QOR; break;
                                        case 0xBB: m_mode = SPIF_MODE_DIOR; break;
                                        case 0xEB: m_mode = SPIF_MODE_QIOR; break;
                                        default: m_mode = SPIF_MODE_READ; break;
                                }
                        }
                } else if (m_state == SPIF_READ_ADDR) {
                        m_address <<= 1;
                        m_address |= dat;
                        if (m_count == 31) {
                                m_state = SPIF_READ_SEND;
                                // printf("Addres: %d\n", m_address);
                        }
                }
                m_count++;
        } else if (sck == 0 && m_last_sck == 1) {        // Falling Edge - Output data
                if (m_state == SPIF_READ_SEND && m_mode == SPIF_MODE_READ) {
                        if (m_count % 8 == 0) {
                                m_data = m_mem[m_address];
                                m_dataMask = 1 << 7;
                                m_address++;
                        }
                        unsigned char send = (m_data & m_dataMask) != 0;
                        m_dataMask >>= 1;
                        m_last_sck = sck;
                        return (unsigned int)send;
                } else if (m_state == SPIF_READ_SEND && m_mode == SPIF_MODE_DOR) {
                        if (m_count % 4 == 0) {
                                m_data = m_mem[m_address];
                                m_dataMask = 1 << 7;
                                m_address++;
                        }
                        unsigned char send1 = (m_data & m_dataMask) != 0;
                        m_dataMask >>= 1;
                        unsigned char send2 = (m_data & m_dataMask) != 0;
                        m_dataMask >>= 1;
                        m_last_sck = sck;
                        return ((unsigned int)send2 << 8) | send1;
                }
        }
        m_last_sck = sck;
        return 0;
}

