/*************************************************
 *File----------LoadProg.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Tuesday Jul 07, 2026 09:04:29 EDT
 *License-------GNU GPL-3.0
 ************************************************/

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
        asm volatile(
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
        asm volatile(
                        "lw %0, 0(%1)\n"
                        :"=r"(data)
                        :"r"(addr)
                    );
        return data;
}

int main(void) {
        // Get ELF header
        union elfHeader elfHeader = getElfHeader();

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

