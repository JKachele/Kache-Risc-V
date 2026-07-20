/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/

module SOC (
        input  wire CLK100MHZ,
        input  wire RESET,

        // input  wire RTC,
        output wire [3:0] LEDS,
        input  wire RXD,
        output wire TXD,

        output wire qspi_sck,
        output wire qspi_cs,
        inout  wire qspi_mosi,
        input  wire qspi_miso
        // inout  wire [3:0] qspi_dq,

        // DDR3 SDRAM
        // output wire        ddr3_reset_n,
        // output wire [0:0]  ddr3_cke,
        // output wire [0:0]  ddr3_ck_p,
        // output wire [0:0]  ddr3_ck_n,
        // output wire [0:0]  ddr3_cs_n,
        // output wire        ddr3_ras_n,
        // output wire        ddr3_cas_n,
        // output wire        ddr3_we_n,
        // output wire [2:0]  ddr3_ba,
        // output wire [13:0] ddr3_addr,
        // output wire [0:0]  ddr3_odt,
        // output wire [1:0]  ddr3_dm,
        // inout  wire [1:0]  ddr3_dqs_p,
        // inout  wire [1:0]  ddr3_dqs_n,
        // inout  wire [15:0] ddr3_dq
);

/*verilator public_flat_rw_on*/
wire clk_100;
wire clk_200;
wire clk_25;
wire axi_clk;
wire reset;

wire RTC = CLK100MHZ;

// Interupts
wire TimerIRQ;

// IO
wire [31:0] IO_addr;
wire [63:0] IO_wData;
wire        IO_rstrb;
wire [7:0]  IO_wstrb;
wire [63:0] IO_rData;
wire        IO_validReady;

// DDR3 AXI
wire [31:0] m_axi_awaddr;
wire [ 7:0] m_axi_awlen;
wire [ 3:0] m_axi_awid;
wire        m_axi_awvalid;
wire        m_axi_awready;
wire [31:0] m_axi_wdata;
wire [ 3:0] m_axi_wstrb;
wire        m_axi_wlast;
wire        m_axi_wvalid;
wire        m_axi_wready;
wire [ 1:0] m_axi_bresp;
wire [ 3:0] m_axi_bid;
wire        m_axi_bvalid;
wire        m_axi_bready;
wire [31:0] m_axi_araddr;
wire [ 7:0] m_axi_arlen;
wire [ 3:0] m_axi_arid;
wire        m_axi_arvalid;
wire        m_axi_arready;
wire [31:0] m_axi_rdata;
wire [ 1:0] m_axi_rresp;
wire        m_axi_rlast;
wire [ 3:0] m_axi_rid;
wire        m_axi_rvalid;
wire        m_axi_rready;

wire [31:0] s_axi_awaddr;
wire [ 7:0] s_axi_awlen;
wire [ 3:0] s_axi_awid;
wire        s_axi_awvalid;
wire        s_axi_awready;
wire [31:0] s_axi_wdata;
wire [ 3:0] s_axi_wstrb;
wire        s_axi_wlast;
wire        s_axi_wvalid;
wire        s_axi_wready;
wire [ 1:0] s_axi_bresp;
wire [ 3:0] s_axi_bid;
wire        s_axi_bvalid;
wire        s_axi_bready;
wire [31:0] s_axi_araddr;
wire [ 7:0] s_axi_arlen;
wire [ 3:0] s_axi_arid;
wire        s_axi_arvalid;
wire        s_axi_arready;
wire [31:0] s_axi_rdata;
wire [ 1:0] s_axi_rresp;
wire        s_axi_rlast;
wire [ 3:0] s_axi_rid;
wire        s_axi_rvalid;
wire        s_axi_rready;
/*verilator public_off*/

RiscV_Top riscv(
        .clk_i(clk_25),
        .reset_i(reset),
        .TimerIRQ_i(TimerIRQ),
        .m_axi_awaddr_o(m_axi_awaddr),
        .m_axi_awlen_o(m_axi_awlen),
        .m_axi_awid_o(m_axi_awid),
        .m_axi_awvalid_o(m_axi_awvalid),
        .m_axi_awready_i(m_axi_awready),
        .m_axi_wdata_o(m_axi_wdata),
        .m_axi_wstrb_o(m_axi_wstrb),
        .m_axi_wlast_o(m_axi_wlast),
        .m_axi_wvalid_o(m_axi_wvalid),
        .m_axi_wready_i(m_axi_wready),
        .m_axi_bresp_i(m_axi_bresp),
        .m_axi_bid_i(m_axi_bid),
        .m_axi_bvalid_i(m_axi_bvalid),
        .m_axi_bready_o(m_axi_bready),
        .m_axi_araddr_o(m_axi_araddr),
        .m_axi_arlen_o(m_axi_arlen),
        .m_axi_arid_o(m_axi_arid),
        .m_axi_arvalid_o(m_axi_arvalid),
        .m_axi_arready_i(m_axi_arready),
        .m_axi_rdata_i(m_axi_rdata),
        .m_axi_rresp_i(m_axi_rresp),
        .m_axi_rlast_i(m_axi_rlast),
        .m_axi_rid_i(m_axi_rid),
        .m_axi_rvalid_i(m_axi_rvalid),
        .m_axi_rready_o(m_axi_rready),
        .IO_addr_o(IO_addr),
        .IO_wData_o(IO_wData),
        .IO_rstrb_o(IO_rstrb),
        .IO_wstrb_o(IO_wstrb),
        .IO_rData_i(IO_rData),
        .IO_validReady_i(IO_validReady)
);

IO io(
        .clk_i(clk_25),
        .reset_i(reset),
        .rtc_i(RTC),
        .IO_addr_i(IO_addr),
        .IO_wData_i(IO_wData),
        .IO_rstrb_i(IO_rstrb),
        .IO_wstrb_i(IO_wstrb),
        .IO_rData_o(IO_rData),
        .IO_validReady_o(IO_validReady),
        .TimerIRQ_o(TimerIRQ),
        .spiClk_o(qspi_sck),
        .spiCs_o(qspi_cs),
        .spiMosi_io(qspi_mosi),
        .spiMiso_i(qspi_miso),
        .txd_o(TXD),
        .leds_o(LEDS)
);

`ifndef BENCH
// AXI_CDC axi_cdc(
//         .s_axi_aclk(clk_25),
//         .s_axi_aresetn(RESET),
//
//         .s_axi_awid(m_axi_awid),
//         .s_axi_awaddr(m_axi_awaddr),
//         .s_axi_awlen(m_axi_awlen),
//         .s_axi_awvalid(m_axi_awvalid),
//         .s_axi_awready(m_axi_awready),
//         .s_axi_wdata(m_axi_wdata),
//         .s_axi_wstrb(m_axi_wstrb),
//         .s_axi_wlast(m_axi_wlast),
//         .s_axi_wvalid(m_axi_wvalid),
//         .s_axi_wready(m_axi_wready),
//         .s_axi_bid(m_axi_bid),
//         .s_axi_bresp(m_axi_bresp),
//         .s_axi_bvalid(m_axi_bvalid),
//         .s_axi_bready(m_axi_bready),
//         .s_axi_arid(m_axi_arid),
//         .s_axi_araddr(m_axi_araddr),
//         .s_axi_arlen(m_axi_arlen),
//         .s_axi_arvalid(m_axi_arvalid),
//         .s_axi_arready(m_axi_arready),
//         .s_axi_rid(m_axi_rid),
//         .s_axi_rdata(m_axi_rdata),
//         .s_axi_rresp(m_axi_rresp),
//         .s_axi_rlast(m_axi_rlast),
//         .s_axi_rvalid(m_axi_rvalid),
//         .s_axi_rready(m_axi_rready),
//
//         .m_axi_aclk(axi_clk),
//         .m_axi_aresetn(RESET),
//
//         .m_axi_awid(s_axi_awid),
//         .m_axi_awaddr(s_axi_awaddr),
//         .m_axi_awlen(s_axi_awlen),
//         .m_axi_awvalid(s_axi_awvalid),
//         .m_axi_awready(s_axi_awready),
//         .m_axi_wdata(s_axi_wdata),
//         .m_axi_wstrb(s_axi_wstrb),
//         .m_axi_wlast(s_axi_wlast),
//         .m_axi_wvalid(s_axi_wvalid),
//         .m_axi_wready(s_axi_wready),
//         .m_axi_bid(s_axi_bid),
//         .m_axi_bresp(s_axi_bresp),
//         .m_axi_bvalid(s_axi_bvalid),
//         .m_axi_bready(s_axi_bready),
//         .m_axi_arid(s_axi_arid),
//         .m_axi_araddr(s_axi_araddr),
//         .m_axi_arlen(s_axi_arlen),
//         .m_axi_arvalid(s_axi_arvalid),
//         .m_axi_arready(s_axi_arready),
//         .m_axi_rid(s_axi_rid),
//         .m_axi_rdata(s_axi_rdata),
//         .m_axi_rresp(s_axi_rresp),
//         .m_axi_rlast(s_axi_rlast),
//         .m_axi_rvalid(s_axi_rvalid),
//         .m_axi_rready(s_axi_rready)
// );

// ArtyDDR3 ddr3 (
//         .clk100_i(clk100),
//         .clk200_i(clk200),
//         .reset_i(RESET),
//         .clkOut_o(axi_clk),
//         .rstOut_o(),
//
//         .s_axi_awaddr_i(s_axi_awaddr),
//         .s_axi_awlen_i(s_axi_awlen),
//         .s_axi_awid_i(s_axi_awid),
//         .s_axi_awvalid_i(s_axi_awvalid),
//         .s_axi_awready_o(s_axi_awready),
//         .s_axi_wdata_i(s_axi_wdata),
//         .s_axi_wstrb_i(s_axi_wstrb),
//         .s_axi_wlast_i(s_axi_wlast),
//         .s_axi_wvalid_i(s_axi_wvalid),
//         .s_axi_wready_o(s_axi_wready),
//         .s_axi_bresp_o(s_axi_bresp),
//         .s_axi_bid_o(s_axi_bid),
//         .s_axi_bvalid_o(s_axi_bvalid),
//         .s_axi_bready_i(s_axi_bready),
//         .s_axi_araddr_i(s_axi_araddr),
//         .s_axi_arlen_i(s_axi_arlen),
//         .s_axi_arid_i(s_axi_arid),
//         .s_axi_arvalid_i(s_axi_arvalid),
//         .s_axi_arready_o(s_axi_arready),
//         .s_axi_rdata_o(s_axi_rdata),
//         .s_axi_rresp_o(s_axi_rresp),
//         .s_axi_rlast_o(s_axi_rlast),
//         .s_axi_rid_o(s_axi_rid),
//         .s_axi_rvalid_o(s_axi_rvalid),
//         .s_axi_rready_i(s_axi_rready),
//
//         .ddr3_reset_n(ddr3_reset_n),
//         .ddr3_cke(ddr3_cke),
//         .ddr3_ck_p(ddr3_ck_p),
//         .ddr3_ck_n(ddr3_ck_n),
//         .ddr3_cs_n(ddr3_cs_n),
//         .ddr3_ras_n(ddr3_ras_n),
//         .ddr3_cas_n(ddr3_cas_n),
//         .ddr3_we_n(ddr3_we_n),
//         .ddr3_ba(ddr3_ba),
//         .ddr3_addr(ddr3_addr),
//         .ddr3_odt(ddr3_odt),
//         .ddr3_dm(ddr3_dm),
//         .ddr3_dqs_p(ddr3_dqs_p),
//         .ddr3_dqs_n(ddr3_dqs_n),
//         .ddr3_dq(ddr3_dq)
// );
`endif

`ifdef BENCH
Clockworks #(
        .SLOW(0)
)CW(
        .CLK(CLK100MHZ),
        .RESET(RESET),
        .clk(clk_25),
        .resetn(reset)
);
`else
ClockworksA7 cw (
        .clkref_i(CLK100MHZ),
        .RESET(RESET),
        .clkBuf_o(clk_100),
        .clk0_o(clk_200),
        .clk1_o(clk_25),
        .resetn(reset)
);
`endif

endmodule

