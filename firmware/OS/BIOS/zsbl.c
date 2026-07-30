/*************************************************
 *File----------zsbl.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Thursday Jul 30, 2026 07:51:40 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include "sbi.h"

#define ELF_ADDR 0x90400000
#define ELF_HEADER_SIZE 52
#define ELF_PHENT_SIZE 32

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

union elfHeader {
        u32 data[ELF_HEADER_SIZE / 4];
        struct {
                u8  ident[16];
                u16 type;
                u16 machine;
                u32 version;
                u32 entry;
                u32 phoff;
                u32 shoff;
                u32 flags;
                u16 ehsize;
                u16 phentsize;
                u16 phnum;
                u16 shentsize;
                u16 shnum;
                u16 shstrndx;
        };
};

union progHeader {
        u32 data[ELF_PHENT_SIZE / 4];
        struct {
                u32 type;
                u32 offset;
                u32 vaddr;
                u32 paddr;
                u32 filesz;
                u32 memsz;
                u32 flags;
                u32 align;
        };
};

u32 getElfData(u32 offset) {
        u32 addr = ELF_ADDR + offset;
        u32 data;
        __asm__ volatile(
                        "lw %0, 0(%1)\n"
                        :"=r"(data)
                        :"r"(addr)
                    );
        return data;
}

// Moves data from offset in elf file to destination address in memory
// size must be alligned and a multiple of 4
void moveData(u32 startOffset, u32 destAddr, u32 size) {
        u32 orig = ELF_ADDR + startOffset;
        u32 dest = destAddr;
        u32 numWords = (size / 4) + 1;
        for (int i = 0; i < numWords; i++) {
                __asm__ volatile(
                                "lw t0, 0(%0)\n"
                                "sw t0, 0(%1)\n"
                                ::"r"(orig), "r"(dest)
                                : "t0", "memory"
                            );
                orig += 4;
                dest += 4;
        }
}

void zero_memory(u32 startAddr, u32 size) {
        u32 addr = startAddr;
        u32 numWords = (size / 4) + 1;
        for (int i = 0; i < numWords; i++) {
                __asm__ volatile(
                                "sw x0, 0(%0)\n"
                                ::"r"(addr)
                                : "memory"
                            );
                addr += 4;
        }
}

union elfHeader getElfHeader() {
        union elfHeader header;
        u32 numWords = ELF_HEADER_SIZE / 4;
        for (int i = 0; i < numWords; i++) {
                header.data[i] = getElfData(i * 4);
        }
        return header;
}

union progHeader getProgHeader(u32 offset) {
        union progHeader header;
        u32 numWords = ELF_PHENT_SIZE / 4;
        for (int i = 0; i < numWords; i++) {
                header.data[i] = getElfData(offset + (i * 4));
        }
        return header;
}

unsigned int getMem(unsigned addr) {
        unsigned int data;
        __asm__ volatile(
                        "lw %0, 0(%1)\n"
                        :"=r"(data)
                        :"r"(addr)
                    );
        return data;
}

int zsbl_main(void) {
        // Get ELF header
        union elfHeader elfHeader = getElfHeader();

        // Verify ELF magic number: 7F 45 4C 46
        if (elfHeader.data[0] != 0x464C457F) {
                print("ERROR: Unrecognised file type\n");
                return 1;
        }

        // Get Program Headers
        union progHeader progs[elfHeader.phnum];
        u32 offset = elfHeader.phoff;
        for (int i = 0; i < elfHeader.phnum; i++) {
                progs[i] = getProgHeader(offset);
                offset += elfHeader.phentsize;
        }

        // Move program data to memory
        for (int i = 0; i < elfHeader.phnum; i++) {
                union progHeader header = progs[i];

                // Ignore non-loadable segments
                if (header.type != 1)
                        continue;

                // Move data from ELF file to memory
                moveData(header.offset, header.paddr, header.filesz);

                // If filesz is less than memsz, zero out the remaining memory
                if (header.filesz < header.memsz)
                        zero_memory(header.paddr + header.filesz, header.memsz - header.filesz);
        }
        // Flush data cache to ensure that the data is written to memory
        __asm__ volatile("fence\n");

        // Jump to start of program
        // __asm__ volatile(
        //                 "jr 0(%0)\n"
        //                 ::"r"(elfHeader.entry)
        //             );

        return 0;
}

