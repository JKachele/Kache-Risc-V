/*************************************************
 *File----------RiscV_Top.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Jul 20, 2026 13:21:30 EDT
 ************************************************/

module RiscV_Top (
        input  wire clk_i,
        input  wire reset_i,

        // Interupts
        input  wire        timerIRQ_i,
        input  wire [63:0] csrTime_i,

        // DDR3 Memory Interface

        // IO
        output wire [31:0] IO_addr_o,
        output wire [63:0] IO_wData_o,
        output wire        IO_rstrb_o,
        output wire [7:0]  IO_wstrb_o,
        input  wire [63:0] IO_rData_i,
        input  wire        IO_validReady_i

);

/*verilator public_flat_rw_on*/
wire [31:0] rvec = 32'h7000_0000;

// MMU
wire [2:0]  page_fault;
wire [33:0] immu_paddr;
wire        immu_valid;
wire [33:0] dmmu_paddr;
wire        dmmu_valid;
wire        tlb_flush;
wire [31:0] mmu_mAddr;
wire        mmu_mRden;
wire [63:0] mmu_mWData;
wire [7:0]  mmu_mWren;
wire [63:0] mmu_mRData;
wire        mmu_mValidReady;

// Cache-Memory Interface
wire         IC_mRden;
wire [31:0]  IC_mAddr;
wire [255:0] IC_mData;
wire         IC_mValid;
wire [31:0]  DC_mAddr;
wire         DC_mRden;
wire [255:0] DC_mWData;
wire [7:0]   DC_mWren;
wire [255:0] DC_mRData;
wire         DC_mValidReady;

// Instruction Cache
wire        IC_strb;
wire        IC_cancel;
wire [31:0] IC_addr;
wire [31:0] IC_satp;
wire [1:0]  IC_priv;
wire        IC_sum;
wire [31:0] IC_data;
wire        IC_valid;
wire        IC_cmp;

// Data Cache
wire [31:0] DC_addr;
wire        DC_flush;
wire        DC_rden;
wire [63:0] DC_wData;
wire [7:0]  DC_wren;
wire [31:0] DC_satp;
wire [1:0]  DC_priv;
wire        DC_mxr;
wire        DC_sum;
wire [63:0] DC_rData;
wire        DC_validReady;
/*verilator public_off*/

Processor CPU(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rvec_i(rvec),
        .timerIRQ_i(timerIRQ_i),
        .csrTime_i(csrTime_i),
        .page_fault_i(page_fault),
        .tlb_flush_o(tlb_flush),
        .IC_strb_o(IC_strb),
        .IC_cancel_o(IC_cancel),
        .IC_addr_o(IC_addr),
        .IC_satp_o(IC_satp),
        .IC_priv_o(IC_priv),
        .IC_sum_o(IC_sum),
        .IC_data_i(IC_data),
        .IC_valid_i(IC_valid),
        .IC_cmp_i(IC_cmp),
        .DC_addr_o(DC_addr),
        .DC_flush_o(DC_flush),
        .DC_rStrb_o(DC_rden),
        .DC_wData_o(DC_wData),
        .DC_wMask_o(DC_wren),
        .DC_satp_o(DC_satp),
        .DC_priv_o(DC_priv),
        .DC_mxr_o(DC_mxr),
        .DC_sum_o(DC_sum),
        .DC_rData_i(DC_rData),
        .DC_validReady_i(DC_validReady)
);

MMU mmu(
        .clk_i(clk_i),
        .reset_i(reset_i),

        .flush_i(tlb_flush),

        .fault_o(page_fault),

        .i_vaddr_i(IC_addr),
        .i_satp_i(IC_satp),
        .i_rden_i(IC_strb),
        .i_priv_i(IC_priv),
        .i_sum_i(IC_sum),
        .i_cancel_i(IC_cancel),
        .i_paddr_o(immu_paddr),
        .i_valid_o(immu_valid),

        .d_vaddr_i(DC_addr),
        .d_satp_i(DC_satp),
        .d_rden_i(DC_rden | (|DC_wren)),
        .d_priv_i(DC_priv),
        .d_write_i(|DC_wren),
        .d_mxr_i(DC_mxr),
        .d_sum_i(DC_sum),
        .d_paddr_o(dmmu_paddr),
        .d_valid_o(dmmu_valid),

        .DMemAddr_o(mmu_mAddr),
        .DMemRden_o(mmu_mRden),
        .DMemWData_o(mmu_mWData),
        .DMemWren_o(mmu_mWren),
        .DMemRData_i(mmu_mRData),
        .DMemValidReady_i(mmu_mValidReady)
);

ICache icache(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .index_offset_i(IC_addr[11:0]),
        .tag_i(immu_paddr[31:12]),
        .rden_i(IC_strb),
        .mmu_valid_i(immu_valid),
        .mmu_fault_i(page_fault[0]),
        .cancel_i(IC_cancel),
        .data_o(IC_data),
        .valid_o(IC_valid),
        .cmp_o(IC_cmp),
        .mAddr_o(IC_mAddr),
        .mRden_o(IC_mRden),
        .mData_i(IC_mData),
        .mValid_i(IC_mValid)
);

DataMem datamem(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .cpu_addr_i(dmmu_paddr[31:0]),
        .cpu_flush_i(DC_flush),
        .cpu_mmu_valid_i(dmmu_valid),
        .cpu_mmu_fault_i(page_fault[2:1]),
        .cpu_rden_i(DC_rden),
        .cpu_wdata_i(DC_wData),
        .cpu_wren_i(DC_wren & {8{dmmu_valid}}),
        .cpu_rdata_o(DC_rData),
        .cpu_validReady_o(DC_validReady),
        .mmu_addr_i(mmu_mAddr),
        .mmu_rden_i(mmu_mRden),
        .mmu_wdata_i(mmu_mWData),
        .mmu_wren_i(mmu_mWren),
        .mmu_rdata_o(mmu_mRData),
        .mmu_validReady_o(mmu_mValidReady),
        .mAddr_o(DC_mAddr),
        .mWData_o(DC_mWData),
        .mRden_o(DC_mRden),
        .mWren_o(DC_mWren),
        .mRData_i(DC_mRData),
        .mValidReady_i(DC_mValidReady),
        .IO_addr_o(IO_addr_o),
        .IO_wData_o(IO_wData_o),
        .IO_rstrb_o(IO_rstrb_o),
        .IO_wstrb_o(IO_wstrb_o),
        .IO_rData_i(IO_rData_i),
        .IO_validReady_i(IO_validReady_i)
);

Memory mem(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rvec_i(rvec),
        .IMemStrb_i(IC_mRden),
        .IMemAddr_i(IC_mAddr),
        .IMemData_o(IC_mData),
        .IMemValid_o(IC_mValid),
        .DMemAddr_i(DC_mAddr),
        .DMemRStrb_i(DC_mRden),
        .DMemWData_i(DC_mWData),
        .DMemWMask_i(DC_mWren),
        .DMemRData_o(DC_mRData),
        .DMemValidReady_o(DC_mValidReady)
);

endmodule

