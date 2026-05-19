/*************************************************
 *File----------spiflash.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Thursday May 14, 2026 20:38:38 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef SPIFLASH_H
#define SPIFLASH_H

#include <stdint.h>
#include <stdlib.h>

class SPIFlash {
	typedef	enum {
		SPIF_IDLE,
		SPIF_READ_CMD,
		SPIF_READ_ADDR,
		SPIF_READ_SEND
	} SPIF_STATE;

        SPIF_STATE m_state;
        char *m_mem;
        int m_last_sck;
        unsigned int m_address;
        unsigned int m_count;
        unsigned int m_memBytes;
        unsigned int m_memMask;
        bool m_debug;
public:
        SPIFlash(const int len = 24, const bool debug = false);
	void load(const char *fname) { load(0, fname); }
	void load(const unsigned addr, const char *fname);
	void load(const uint32_t offset, const char *data, const uint32_t len);

	int operator()(const int csn, const int sck, const char dat);
};

#endif

