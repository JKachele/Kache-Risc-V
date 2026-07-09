/*************************************************
 *File----------LoadProg.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Tuesday Jul 07, 2026 09:04:29 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#define ELF_ADDR 0x80400000

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

struct elfHeader {
        u16 type;
        u16 machine;
        u32 version;
        u32 entry;
        u32 phoff;
        u32 shoff;
        u16 flags;
        u16 ehsize;
        u16 phentsize;
        u16 phnum;
        u16 shentsize;
        u16 shnum;
};

struct progHeader {
        u32 type;
        u32 offset;
        u32 vaddr;
        u32 paddr;
        u32 filesz;
        u32 memsz;
        u32 flags;
        u32 align;
};

u32 getElfData(u32 offset, int numBytes) {
        u32 addr = ELF_ADDR + offset;
        u32 data;
        asm volatile(
                        "lw %0, 0(%1)\n"
                        :"=r"(data)
                        :"r"(addr)
                    );
        u32 mask = 0xFFFFFFFF >> (8 * (4 - numBytes));
        return data & mask;
}

// Moves data from offset in elf file to destination address in memory
// size must be alligned and a multiple of 4
void moveData(u32 startOffset, u32 destAddr, u32 size) {
        u32 orig = ELF_ADDR + startOffset;
        u32 dest = destAddr;
        u32 numWords = size / 4;
        for (int i = 0; i < numWords; i++) {
                asm volatile(
                                "lw t0, 0(%0)\n"
                                "sw t0, 0(%1)\n"
                                ::"r"(orig), "r"(dest)
                                : "t0", "memory"
                            );
                orig += 4;
                dest += 4;
        }

        // Flush data cache to ensure that the data is written to memory
        asm volatile("fence\n");
}

struct elfHeader getElfHeader() {
        struct elfHeader header;
        header.type      = getElfData(0x10, 2);
        header.machine   = getElfData(0x12, 2);
        header.version   = getElfData(0x14, 4);
        header.entry     = getElfData(0x18, 4);
        header.phoff     = getElfData(0x1C, 4);
        header.shoff     = getElfData(0x20, 4);
        header.flags     = getElfData(0x24, 4);
        header.ehsize    = getElfData(0x28, 2);
        header.phentsize = getElfData(0x2A, 2);
        header.phnum     = getElfData(0x2C, 2);
        header.shentsize = getElfData(0x30, 2);
        header.shnum     = getElfData(0x34, 2);
        return header;
}

struct progHeader getProgHeader(u32 offset) {
        struct progHeader header;
        header.type   = getElfData(offset + 0x00, 4);
        header.offset = getElfData(offset + 0x04, 4);
        header.vaddr  = getElfData(offset + 0x08, 4);
        header.paddr  = getElfData(offset + 0x0C, 4);
        header.filesz = getElfData(offset + 0x10, 4);
        header.memsz  = getElfData(offset + 0x14, 4);
        header.flags  = getElfData(offset + 0x18, 4);
        header.align  = getElfData(offset + 0x1C, 4);
        return header;
}

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
        // Get ELF header
        struct elfHeader elfHeader = getElfHeader();

        // Get Program Headers
        struct progHeader progs[elfHeader.phnum];
        u32 offset = elfHeader.phoff;
        for (int i = 0; i < elfHeader.phnum; i++) {
                progs[i] = getProgHeader(offset);
                offset += elfHeader.phentsize;
        }

        // Move program data to memory
        for (int i = 0; i < elfHeader.phnum; i++) {
                struct progHeader header = progs[i];
                if (header.type != 1) continue;
                moveData(header.offset, header.paddr, header.filesz);
        }

        // Jump to start of program
        asm volatile(
                        "jr 0(%0)\n"
                        ::"r"(elfHeader.entry)
                    );

        return 0;
}

