/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module SOC (
        input  wire CLK,
        input  wire RESET,
        input  wire [31:0] rvec,

        output wire [3:0] LEDS,
        input  wire RXD,
        output wire TXD,

        output wire qspi_sck,
        output wire qspi_cs,
        inout  wire qspi_mosi,
        input  wire qspi_miso,
        // inout  wire [3:0] qspi_dq,

        // DDR3 SDRAM
        output wire        ddr3_reset_n,
        output wire [0:0]  ddr3_cke,
        output wire [0:0]  ddr3_ck_p,
        output wire [0:0]  ddr3_ck_n,
        output wire [0:0]  ddr3_cs_n,
        output wire        ddr3_ras_n,
        output wire        ddr3_cas_n,
        output wire        ddr3_we_n,
        output wire [2:0]  ddr3_ba,
        output wire [13:0] ddr3_addr,
        output wire [0:0]  ddr3_odt,
        output wire [1:0]  ddr3_dm,
        inout  wire [1:0]  ddr3_dqs_p,
        inout  wire [1:0]  ddr3_dqs_n,
        inout  wire [15:0] ddr3_dq
);

/*verilator public_flat_rw_on*/
wire clk;
wire reset;
wire clk0;
wire clk1;

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

// DDR3 AXI
wire [31:0] axi_awaddr;
wire [ 7:0] axi_awlen;
wire [ 3:0] axi_awid;
wire        axi_awvalid;
wire        axi_awready;
wire [31:0] axi_wdata;
wire [ 3:0] axi_wstrb;
wire        axi_wlast;
wire        axi_wvalid;
wire        axi_wready;
wire [ 1:0] axi_bresp;
wire [ 3:0] axi_bid;
wire        axi_bvalid;
wire        axi_bready;
wire [31:0] axi_araddr;
wire [ 7:0] axi_arlen;
wire [ 3:0] axi_arid;
wire        axi_arvalid;
wire        axi_arready;
wire [31:0] axi_rdata;
wire [ 1:0] axi_rresp;
wire        axi_rlast;
wire [ 3:0] axi_rid;
wire        axi_rvalid;
wire        axi_rready;
/*verilator public_off*/

Processor CPU(
        .clk_i(clk),
        .reset_i(reset),
        .rvec_i(rvec),
        .ICacheStrb_o(ICacheStrb),
        .ICacheCancel_o(ICacheCancel),
        .ICacheAddr_o(ICacheAddr),
        .ICacheData_i(ICacheData),
        .ICacheValid_i(ICacheValid),
        .ICacheCmp_i(ICacheCmp),
        .DMemAddr_o(DCacheAddr),
        .DMemRStrb_o(DCacheRden),
        .DMemWData_o(DCacheWData),
        .DMemWMask_o(DCacheWren),
        .DMemRData_i(DCacheRData),
        .DMemValidReady_i(DCacheValidReady)
);

ICache icache(
        .clk_i(clk),
        .reset_i(reset),
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

DCache dcache(
        .clk_i(clk),
        .reset_i(reset),
        .addr_i(DCacheAddr),
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
        .mValidReady_i(DC_mValidReady)
);

Memory mem(
        .clk_i(clk),
        .reset_i(reset),
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
        .leds_o(LEDS),
        .txd_o(TXD),
        .spiClk_o(qspi_sck),
        .spiCs_o(qspi_cs),
        .spiMosi_io(qspi_mosi),
        .spiMiso_i(qspi_miso)
);

`ifndef BENCH
ArtyDDR3 ddr3 (
        .clk100_i(clk0),
        .clk200_i(clk1),
        .reset_i(RESET),
        .clkOut_o(clkOut),
        .rstOut_o(reset),

        .s_axi_awaddr_i(axi_awaddr),
        .s_axi_awlen_i(axi_awlen),
        .s_axi_awid_i(axi_awid),
        .s_axi_awvalid_i(axi_awvalid),
        .s_axi_awready_o(axi_awready),
        .s_axi_wdata_i(axi_wdata),
        .s_axi_wstrb_i(axi_wstrb),
        .s_axi_wlast_i(axi_wlast),
        .s_axi_wvalid_i(axi_wvalid),
        .s_axi_wready_o(axi_wready),
        .s_axi_bresp_o(axi_bresp),
        .s_axi_bid_o(axi_bid),
        .s_axi_bvalid_o(axi_bvalid),
        .s_axi_bready_i(axi_bready),
        .s_axi_araddr_i(axi_araddr),
        .s_axi_arlen_i(axi_arlen),
        .s_axi_arid_i(axi_arid),
        .s_axi_arvalid_i(axi_arvalid),
        .s_axi_arready_o(axi_arready),
        .s_axi_rdata_o(axi_rdata),
        .s_axi_rresp_o(axi_rresp),
        .s_axi_rlast_o(axi_rlast),
        .s_axi_rid_o(axi_rid),
        .s_axi_rvalid_o(axi_rvalid),
        .s_axi_rready_i(axi_rready),

        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_ba(ddr3_ba),
        .ddr3_addr(ddr3_addr),
        .ddr3_odt(ddr3_odt),
        .ddr3_dm(ddr3_dm),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dq(ddr3_dq)
);
`endif

`ifdef BENCH
Clockworks #(
        .SLOW(0)
)CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);
`else
ClockworksA7 cw (
        .clkref_i(CLK),
        .clk0_o(clk0),
        .clk1_o(clk1),
        .clk2_o(clk)
);
`endif

endmodule
/* verilator lint_on WIDTH */

