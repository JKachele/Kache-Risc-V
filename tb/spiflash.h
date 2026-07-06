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
                SPIF_DUMMY,
		SPIF_READ_SEND
	} SPIF_STATE;

        typedef enum {
                SPIF_MODE_READ,
                SPIF_MODE_DOR,
                SPIF_MODE_QOR,
                SPIF_MODE_DIOR,
                SPIF_MODE_QIOR
        } SPIF_MODE;

        SPIF_STATE m_state;
        SPIF_MODE m_mode;
        unsigned char *m_mem;
        int m_last_sck;
        unsigned int m_command;
        unsigned int m_address;
        unsigned int m_count;
        unsigned int m_memBytes;
        unsigned int m_memMask;
        unsigned char m_data;
        unsigned char m_dataMask;
        bool m_debug;
public:

        SPIFlash(const int len = 24, const bool debug = false);
	void load(const char *fname) { load(0, fname); }
	void load(const unsigned addr, const char *fname);
	void load(const uint32_t offset, const char *data, const uint32_t len);
        void print(const unsigned addr, const uint32_t len);

	unsigned int operator()(const int csn, const int sck, const char dat);
};

#endif

