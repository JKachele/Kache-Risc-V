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

        // AXI4 Memory Interface
        output reg  [31:0]  m_axi_awaddr_o,
        output wire [ 7:0]  m_axi_awlen_o,
        output wire [ 3:0]  m_axi_awid_o,
        output reg          m_axi_awvalid_o,
        input  wire         m_axi_awready_i,
        output reg  [31:0]  m_axi_wdata_o,
        output reg  [ 3:0]  m_axi_wstrb_o,
        output reg          m_axi_wlast_o,
        output reg          m_axi_wvalid_o,
        input  wire         m_axi_wready_i,
        input  wire [ 1:0]  m_axi_bresp_i,
        input  wire [ 3:0]  m_axi_bid_i,
        input  wire         m_axi_bvalid_i,
        output wire         m_axi_bready_o,

        output reg  [31:0]  m_axi_araddr_o,
        output wire [ 7:0]  m_axi_arlen_o,
        output wire [ 3:0]  m_axi_arid_o,
        output reg          m_axi_arvalid_o,
        input  wire         m_axi_arready_i,
        input  wire [31:0]  m_axi_rdata_i,
        input  wire [ 1:0]  m_axi_rresp_i,
        input  wire         m_axi_rlast_i,
        input  wire [ 3:0]  m_axi_rid_i,
        input  wire         m_axi_rvalid_i,
        output reg          m_axi_rready_o,

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
wire        ICacheStrb;
wire        ICacheCancel;
wire [31:0] ICacheAddr;
wire [31:0] ICacheData;
wire        ICacheValid;
wire        ICacheCmp;

// Data Cache
wire [31:0] DCacheAddr;
wire        DCacheFlush;
wire        DCacheRden;
wire [63:0] DCacheWData;
wire [7:0]  DCacheWren;
wire [63:0] DCacheRData;
wire        DCacheValidReady;

//Memory
wire [31:0] DMemAddr;
wire        DMemRStrb;
wire [63:0] DMemRData;
wire [63:0] DMemWData;
wire [7:0]  DMemWMask;
wire        DMemValidReady;
/*verilator public_off*/

Processor CPU(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rvec_i(rvec),
        .timerIRQ_i(timerIRQ_i),
        .csrTime_i(csrTime_i),
        .ICacheStrb_o(ICacheStrb),
        .ICacheCancel_o(ICacheCancel),
        .ICacheAddr_o(ICacheAddr),
        .ICacheData_i(ICacheData),
        .ICacheValid_i(ICacheValid),
        .ICacheCmp_i(ICacheCmp),
        .DMemAddr_o(DCacheAddr),
        .DMemFlush_o(DCacheFlush),
        .DMemRStrb_o(DCacheRden),
        .DMemWData_o(DCacheWData),
        .DMemWMask_o(DCacheWren),
        .DMemRData_i(DCacheRData),
        .DMemValidReady_i(DCacheValidReady)
);

ICache icache(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .addr_i(ICacheAddr),
        .rden_i(ICacheStrb),
        .cancel_i(ICacheCancel),
        .data_o(ICacheData),
        .valid_o(ICacheValid),
        .cmp_o(ICacheCmp),
        .mAddr_o(IC_mAddr),
        .mRden_o(IC_mRden),
        .mData_i(IC_mData),
        .mValid_i(IC_mValid)
);

DataMem datamem(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .addr_i(DCacheAddr),
        .flush_i(DCacheFlush),
        .rden_i(DCacheRden),
        .wdata_i(DCacheWData),
        .wren_i(DCacheWren),
        .rdata_o(DCacheRData),
        .validReady_o(DCacheValidReady),
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
        .DMemValidReady_o(DC_mValidReady),
        .m_axi_awaddr_o(m_axi_awaddr_o),
        .m_axi_awlen_o(m_axi_awlen_o),
        .m_axi_awid_o(m_axi_awid_o),
        .m_axi_awvalid_o(m_axi_awvalid_o),
        .m_axi_awready_i(m_axi_awready_i),
        .m_axi_wdata_o(m_axi_wdata_o),
        .m_axi_wstrb_o(m_axi_wstrb_o),
        .m_axi_wlast_o(m_axi_wlast_o),
        .m_axi_wvalid_o(m_axi_wvalid_o),
        .m_axi_wready_i(m_axi_wready_i),
        .m_axi_bresp_i(m_axi_bresp_i),
        .m_axi_bid_i(m_axi_bid_i),
        .m_axi_bvalid_i(m_axi_bvalid_i),
        .m_axi_bready_o(m_axi_bready_o),
        .m_axi_araddr_o(m_axi_araddr_o),
        .m_axi_arlen_o(m_axi_arlen_o),
        .m_axi_arid_o(m_axi_arid_o),
        .m_axi_arvalid_o(m_axi_arvalid_o),
        .m_axi_arready_i(m_axi_arready_i),
        .m_axi_rdata_i(m_axi_rdata_i),
        .m_axi_rresp_i(m_axi_rresp_i),
        .m_axi_rlast_i(m_axi_rlast_i),
        .m_axi_rid_i(m_axi_rid_i),
        .m_axi_rvalid_i(m_axi_rvalid_i),
        .m_axi_rready_o(m_axi_rready_o)
);

endmodule

