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
wire clk_100;   // 100 MHz - Buffered System Clock for DDR3 MIG
wire clk_200;   // 200 MHz - Reference Clock for DDR3 MIG
wire clk_25;    // 25 MHz  - System Clock for RiscV and IO
wire clk_timer; // 10 MHz  - Timer Clock MTIME register
wire reset;     // Active High Reset

// Interupts
wire        timerIRQ;
wire [63:0] csrTime;

// IO
wire [31:0] IO_addr;
wire [63:0] IO_wData;
wire        IO_rstrb;
wire [7:0]  IO_wstrb;
wire [63:0] IO_rData;
wire        IO_validReady;

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

RiscV_Top riscv(
        .clk_i(clk_25),
        .reset_i(reset),
        .timerIRQ_i(timerIRQ),
        .csrTime_i(csrTime),
        .m_axi_awaddr_o(axi_awaddr),
        .m_axi_awlen_o(axi_awlen),
        .m_axi_awid_o(axi_awid),
        .m_axi_awvalid_o(axi_awvalid),
        .m_axi_awready_i(axi_awready),
        .m_axi_wdata_o(axi_wdata),
        .m_axi_wstrb_o(axi_wstrb),
        .m_axi_wlast_o(axi_wlast),
        .m_axi_wvalid_o(axi_wvalid),
        .m_axi_wready_i(axi_wready),
        .m_axi_bresp_i(axi_bresp),
        .m_axi_bid_i(axi_bid),
        .m_axi_bvalid_i(axi_bvalid),
        .m_axi_bready_o(axi_bready),
        .m_axi_araddr_o(axi_araddr),
        .m_axi_arlen_o(axi_arlen),
        .m_axi_arid_o(axi_arid),
        .m_axi_arvalid_o(axi_arvalid),
        .m_axi_arready_i(axi_arready),
        .m_axi_rdata_i(axi_rdata),
        .m_axi_rresp_i(axi_rresp),
        .m_axi_rlast_i(axi_rlast),
        .m_axi_rid_i(axi_rid),
        .m_axi_rvalid_i(axi_rvalid),
        .m_axi_rready_o(axi_rready),
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
        .timerClk_i(clk_timer),
        .IO_addr_i(IO_addr),
        .IO_wData_i(IO_wData),
        .IO_rstrb_i(IO_rstrb),
        .IO_wstrb_i(IO_wstrb),
        .IO_rData_o(IO_rData),
        .IO_validReady_o(IO_validReady),
        .timerIRQ_o(timerIRQ),
        .csrTime_o(csrTime),
        .spiClk_o(qspi_sck),
        .spiCs_o(qspi_cs),
        .spiMosi_io(qspi_mosi),
        .spiMiso_i(qspi_miso),
        .txd_o(TXD),
        .leds_o(LEDS)
);

`ifndef BENCH
// ArtyDDR3 ddr3 (
//         .clk100_i(clk_100),
//         .clk200_i(clk_200),
//         .clk25_i(clk_25),
//         .reset_i(RESET),
//         .clkOut_o(),
//         .rstOut_o(),
//
//         .s_axi_awaddr(axi_awaddr),
//         .s_axi_awlen(axi_awlen),
//         .s_axi_awid(axi_awid),
//         .s_axi_awvalid(axi_awvalid),
//         .s_axi_awready(axi_awready),
//         .s_axi_wdata(axi_wdata),
//         .s_axi_wstrb(axi_wstrb),
//         .s_axi_wlast(axi_wlast),
//         .s_axi_wvalid(axi_wvalid),
//         .s_axi_wready(axi_wready),
//         .s_axi_bresp(axi_bresp),
//         .s_axi_bid(axi_bid),
//         .s_axi_bvalid(axi_bvalid),
//         .s_axi_bready(axi_bready),
//         .s_axi_araddr(axi_araddr),
//         .s_axi_arlen(axi_arlen),
//         .s_axi_arid(axi_arid),
//         .s_axi_arvalid(axi_arvalid),
//         .s_axi_arready(axi_arready),
//         .s_axi_rdata(axi_rdata),
//         .s_axi_rresp(axi_rresp),
//         .s_axi_rlast(axi_rlast),
//         .s_axi_rid(axi_rid),
//         .s_axi_rvalid(axi_rvalid),
//         .s_axi_rready(axi_rready),
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

// Timer Clock: 1.5625 MHz
reg [3:0] clk_div;
always @(posedge CLK100MHZ) begin
        if (reset) begin
                clk_div <= 4'b0;
        end else begin
                clk_div <= clk_div + 1;
        end
end
`ifdef BENCH
assign clk_timer = clk_div[1];
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
        .clk0_o(clk_100),
        .clk1_o(clk_200),
        .clk2_o(clk_25),
        .clk3_o(clk_timer),
        .resetn(reset)
);
`endif

endmodule

