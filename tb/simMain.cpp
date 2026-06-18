#include <stdio.h>
#include <vector>
#include "VSOC.h"
#include "VSOC___024root.h"
#include "testbench.h"
#include "uartsim.h"
#include "spiflash.h"
#include "riscVDis.h"

#define HALT                    SOC__DOT__CPU__DOT__HALT
#define D_stall                 SOC__DOT__CPU__DOT__D_stall
#define dataHazard              SOC__DOT__CPU__DOT__dataHazard
#define DE_pc                   SOC__DOT__CPU__DOT__DE_PC
#define DE_instr                SOC__DOT__CPU__DOT__DE_instr
#define E_takeBranch            SOC__DOT__CPU__DOT__E_takeBranch
#define DE_predictBranch        SOC__DOT__CPU__DOT__DE_predictBranch
#define DE_predictRA            SOC__DOT__CPU__DOT__DE_predictRA
#define E_JALRaddr              SOC__DOT__CPU__DOT__execute__DOT__E_JALRaddr
#define CYCLE                   SOC__DOT__CPU__DOT__csr__DOT__CSR_cycle
#define INSTRET                 SOC__DOT__CPU__DOT__csr__DOT__CSR_instret
#define F_pc                    SOC__DOT__CPU__DOT__fetch__DOT__PC
#define ICacheHit               SOC__DOT__icache__DOT__C_hit
#define ICacheSplit             SOC__DOT__CPU__DOT__fetch__DOT__ICacheSplit
#define DCacheState             SOC__DOT__dcache__DOT__C_curState

#define Reg_A0                  SOC__DOT__CPU__DOT__registers__DOT__reg_10
#define Reg_A1                  SOC__DOT__CPU__DOT__registers__DOT__reg_11
#define Reg_FA0                 SOC__DOT__CPU__DOT__registers__DOT__reg_F10
#define Reg_FA1                 SOC__DOT__CPU__DOT__registers__DOT__reg_F11
#define Reg_FA2                 SOC__DOT__CPU__DOT__registers__DOT__reg_F12
#define Reg_FA3                 SOC__DOT__CPU__DOT__registers__DOT__reg_F13
#define Reg_FA4                 SOC__DOT__CPU__DOT__registers__DOT__reg_F14
#define Reg_FA5                 SOC__DOT__CPU__DOT__registers__DOT__reg_F15
#define Reg_FS0                 SOC__DOT__CPU__DOT__registers__DOT__reg_F8

class SOC_TB : public TESTB<VSOC> {
        // Statistics counters
        IData nbBranch = 0;
        IData nbBranchHit = 0;
        IData nbJAL  = 0;
        IData nbJALR = 0;
        IData nbJALRhit = 0;
        IData nbLoad = 0;
        IData nbStore = 0;
        IData nbLoadHazard = 0;
        IData nbRV32M = 0;
        IData nbMULDIV = 0;
        IData nbFPU = 0;
        IData nbAMO = 0;
        IData nbICache = 0;
        IData nbICacheHit = 0;
        IData nbICacheSplit = 0;
        IData nbDCacheMiss = 0;
        IData prevPC = 0;
        CData prevDCacheState = 0;

        // Program Execution
        IData prevDE_PC = 0;

        void updateStats(void) {
                if (m_core->RESET == 0 && rootp->D_stall == 0) {
                        if (riscV_isBranch(rootp->DE_instr)) {
                                nbBranch++;
                                if (rootp->E_takeBranch ==
                                                rootp->DE_predictBranch) {
                                        nbBranchHit++;
                                }
                        }
                        if (riscV_isJAL(rootp->DE_instr)) {
                                nbJAL++;
                        }
                        if (riscV_isJALR(rootp->DE_instr)) {
                                nbJALR++;
                                if (rootp->DE_predictRA == rootp->E_JALRaddr) {
                                        nbJALRhit++;
                                }
                        }
                }
                if (riscV_isLoad(rootp->DE_instr))
                        nbLoad++;
                if (riscV_isStore(rootp->DE_instr))
                        nbStore++;
                if (riscV_isMul(rootp->DE_instr) || riscV_isDiv(rootp->DE_instr))
                        nbMULDIV++;
                if (riscV_isFPU(rootp->DE_instr))
                        nbFPU++;
                if (riscV_isAMO(rootp->DE_instr))
                        nbAMO++;
                if (rootp->dataHazard == 1)
                        nbLoadHazard++;
                if (rootp->F_pc != prevPC) {
                        if (rootp->ICacheHit)
                                nbICacheHit++;
                        if (rootp->ICacheSplit)
                                nbICacheSplit++;
                        nbICache++;
                } 
                if (rootp->DCacheState != 0 && prevDCacheState == 0) {
                        nbDCacheMiss++;
                }
                prevDCacheState = rootp->DCacheState;
                prevPC = rootp->F_pc;
        }

public:
        IData prevLEDS;
        CData prevCLK;
        CData prevSpiCs = 1;

        SPIFlash *m_flash;

        FILE *programLog;

        SOC_TB(void) {
                m_flash = new SPIFlash();
        }

        virtual void tick(void) {
                TESTB<VSOC>::tickUp();
                unsigned int qspi_miso = (*m_flash)(m_core->qspi_cs, m_core->qspi_sck, m_core->qspi_mosi__out);
                m_core->qspi_miso = (char)(qspi_miso & 0xff);
                m_core->qspi_mosi = (char)((qspi_miso >> 8) & 0xff);
                // m_core->qspi_miso = (*m_flash)(m_core->qspi_cs, m_core->qspi_sck, m_core->qspi_mosi);
                TESTB<VSOC>::tickDown();
                (*m_flash)(m_core->qspi_cs, m_core->qspi_sck, m_core->qspi_mosi__out);

                prevLEDS = m_core->LEDS;
                prevCLK = m_core->rootp->SOC__DOT__clk;

                if (m_core->rootp->SOC__DOT__DMemWMask != 0 &&
                                m_core->rootp->SOC__DOT__DMemRStrb != 0) {
                        printf("Read-write collision detected: ");
                        printf("DE_pc = %x\n", m_core->rootp->SOC__DOT__CPU__DOT__DE_PC);
                }

                updateStats();
        }

        void recordExecution(void) {
                IData pc = rootp->DE_pc;
                IData instr = rootp->DE_instr;
                if (pc != prevDE_PC && !riscV_isNOP(instr)) {
                        fprintf(programLog, "%08x: %08x\n", pc, instr);
                        // fprintf(programLog, "A0: %08x ", rootp->Reg_A0);
                        // fprintf(programLog, "FA0: %08lx ", rootp->Reg_FA0 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FA1: %08lx ", rootp->Reg_FA1 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FA2: %08lx ", rootp->Reg_FA2 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FA3: %08lx ", rootp->Reg_FA3 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FA4: %08lx ", rootp->Reg_FA4 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FA5: %08lx ", rootp->Reg_FA5 & 0x00000000FFFFFFFF);
                        // fprintf(programLog, "FS0: %08lx\n", rootp->Reg_FS0 & 0x00000000FFFFFFFF);
                }
                prevDE_PC = pc;
        }

        void printFReg(const char *name, IData reg) {
                float  f = *(float*)&reg;
                printf("%s: %x (%f)\n", name, reg, f);
        }

        void printIReg(const char *name, IData reg) {
                printf("%s: %x (%d)\n", name, reg, reg);
        }

        virtual bool done(void) {
                static int clocksAfterHalt = 0;
                if (rootp->HALT == 1)
                        clocksAfterHalt++;

                // Exit 1 clock after halt to allow simulation to finish
                if (clocksAfterHalt > 1)
                        return true;

                // Default
                return TESTB<VSOC>::done();
        }

        void printStatusReport(void) {
                u64 cycle = rootp->CYCLE;
                u64 instret = rootp->INSTRET;
                float cpi = (cycle*1.0)/(instret*1.0);
                float ipc = (instret*1.0)/(cycle*1.0);

                int nbDCache = nbLoad + nbStore;
                int nbDCacheHit = nbDCache - nbDCacheMiss;

                printf("\n----------------------------\n");
                printf("Simulated processor's report\n");
                printf("----------------------------\n");
                printf("ICache hit   = %3.3f\%%\n", nbICacheHit*100.0/nbICache);
                // printf("(%d Misses)\n",             nbICache - nbICacheHit);
                printf("DCache hit   = %3.3f\%%\n", nbDCacheHit*100.0/nbDCache);
                // printf("(%d Misses)\n",             nbDCacheMiss);
                printf("ICache Split = %3.3f\%%\n", nbICacheSplit*100.0/nbICache);
                printf("Branch hit   = %3.3f\%%\n", nbBranchHit*100.0/nbBranch);
                printf("JALR   hit   = %3.3f\%%\n", nbJALRhit*100.0/nbJALR);
                printf("Load hzrds   = %3.3f\%%\n", nbLoadHazard*100.0/nbLoad);
                printf("Cycles       = %ld\n", cycle);
                printf("Instret      = %ld\n", instret);
                printf("CPI/IPC      = %3.3f/%3.3f\n",cpi, ipc);

                printf("Instr. mix = (");
                printf("Branch:%3.3f\%% | ",            nbBranch*100.0/instret);
                printf("JAL:%3.3f\%% | ",               nbJAL*100.0/instret);
                printf("JALR:%3.3f\%% | ",              nbJALR*100.0/instret);
                printf("Load:%3.3f\%% | ",              nbLoad*100.0/instret);
                printf("Store:%3.3f\%% | ",             nbStore*100.0/instret);
                printf("MUL/DIV/REM:%3.3f\%% | ",       nbMULDIV*100.0/instret);
                printf("FPU:%3.3f\%% | ",               nbFPU*100.0/instret);
                printf("AMO:%3.3f\%%",                  nbAMO*100.0/instret);
                printf(")\n");

                // printIReg("A0", rootp->Reg_A0);
                // printIReg("A0", rootp->Reg_A1);
        }

};

int main(int argc, char **argv) {
        printf("----------------------------\n");
        printf("Beginning simulation...\n");
        printf("----------------------------\n");

        // Initialize Verilators variables
        Verilated::commandArgs(argc, argv);

        // Create an instance of our module under test
        SOC_TB *tb = new SOC_TB();

        tb->programLog = fopen("Program.txt", "w");

        tb->m_flash->load("../bin/firmware.bin");
        // tb->m_flash->print(0, 16);


        UARTSIM *uart;
        int port = 0;
        unsigned setup = 868;
        unsigned clocks = 0;
        unsigned baudclocks;

        uart = new UARTSIM(port);
        uart->setup(setup);
        baudclocks = setup & 0xfffffff;

        // tb->opentrace("trace.vcd");

        tb->m_core->rvec = 0x70000000;
        tb->reset();

        int rxPrev = 1;
        while (!tb->done()) {
                tb->tick();
                // tb->recordExecution();
                // tb->m_core->RXD = (*uart)(tb->m_core->TXD);
                // clocks++;
        }
        tb->printStatusReport();

        fclose(tb->programLog);
        delete tb;
        return 0;
}
