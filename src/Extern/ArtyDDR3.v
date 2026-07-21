/*************************************************
 *File----------ArtyDDR3.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jun 18, 2026 13:42:39 UTC
 ************************************************/

module ArtyDDR3 (
        input  wire        clk100_i,
        input  wire        clk200_i,
        input  wire        clk25_i,
        input  wire        reset_i,
        output wire        clkOut_o,
        output wire        rstOut_o,
        // AXI4 Interface
        input  wire [31:0] s_axi_awaddr,
        input  wire [ 7:0] s_axi_awlen,
        input  wire [ 3:0] s_axi_awid,
        input  wire        s_axi_awvalid,
        output wire        s_axi_awready,
        input  wire [31:0] s_axi_wdata,
        input  wire [ 3:0] s_axi_wstrb,
        input  wire        s_axi_wlast,
        input  wire        s_axi_wvalid,
        output wire        s_axi_wready,
        output wire [ 1:0] s_axi_bresp,
        output wire [ 3:0] s_axi_bid,
        output wire        s_axi_bvalid,
        input  wire        s_axi_bready,
        input  wire [31:0] s_axi_araddr,
        input  wire [ 7:0] s_axi_arlen,
        input  wire [ 3:0] s_axi_arid,
        input  wire        s_axi_arvalid,
        output wire        s_axi_arready,
        output wire [31:0] s_axi_rdata,
        output wire [ 1:0] s_axi_rresp,
        output wire        s_axi_rlast,
        output wire [ 3:0] s_axi_rid,
        output wire        s_axi_rvalid,
        input  wire        s_axi_rready,

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

// CDC -> MIG AXI signals
wire [31:0] ddr_axi_awaddr;
wire [ 7:0] ddr_axi_awlen;
wire [ 3:0] ddr_axi_awid;
wire        ddr_axi_awvalid;
wire        ddr_axi_awready;
wire [31:0] ddr_axi_wdata;
wire [ 3:0] ddr_axi_wstrb;
wire        ddr_axi_wlast;
wire        ddr_axi_wvalid;
wire        ddr_axi_wready;
wire [ 1:0] ddr_axi_bresp;
wire [ 3:0] ddr_axi_bid;
wire        ddr_axi_bvalid;
wire        ddr_axi_bready;
wire [31:0] ddr_axi_araddr;
wire [ 7:0] ddr_axi_arlen;
wire [ 3:0] ddr_axi_arid;
wire        ddr_axi_arvalid;
wire        ddr_axi_arready;
wire [31:0] ddr_axi_rdata;
wire [ 1:0] ddr_axi_rresp;
wire        ddr_axi_rlast;
wire [ 3:0] ddr_axi_rid;
wire        ddr_axi_rvalid;
wire        ddr_axi_rready;

axi_clock_converter_0 axi_cdc(
        .s_axi_aclk(clk25_i),
        .s_axi_aresetn(RESET),

        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(3'b010),
        .s_axi_awburst(2'b01),
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'h2),
        .s_axi_awprot(3'b010),
        .s_axi_awregion(4'b0),
        .s_axi_awqos(4'b0),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(3'b010),
        .s_axi_arburst(2'b01),
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'h2),
        .s_axi_arprot(3'b010),
        .s_axi_arregion(4'b0),
        .s_axi_arqos(4'b0),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .m_axi_aclk(ddr_axi_aclk),
        .m_axi_aresetn(ddr_rst),

        .m_axi_awid(ddr_axi_awid),
        .m_axi_awaddr(ddr_axi_awaddr),
        .m_axi_awlen(ddr_axi_awlen),
        .m_axi_awsize(),
        .m_axi_awburst(),
        .m_axi_awlock(),
        .m_axi_awcache(),
        .m_axi_awprot(),
        .m_axi_awregion(),
        .m_axi_awqos(),
        .m_axi_awvalid(ddr_axi_awvalid),
        .m_axi_awready(ddr_axi_awready),
        .m_axi_wdata(ddr_axi_wdata),
        .m_axi_wstrb(ddr_axi_wstrb),
        .m_axi_wlast(ddr_axi_wlast),
        .m_axi_wvalid(ddr_axi_wvalid),
        .m_axi_wready(ddr_axi_wready),
        .m_axi_bid(ddr_axi_bid),
        .m_axi_bresp(ddr_axi_bresp),
        .m_axi_bvalid(ddr_axi_bvalid),
        .m_axi_bready(ddr_axi_bready),
        .m_axi_arid(ddr_axi_arid),
        .m_axi_araddr(ddr_axi_araddr),
        .m_axi_arlen(ddr_axi_arlen),
        .m_axi_arsize(),
        .m_axi_arburst(),
        .m_axi_arlock(),
        .m_axi_arcache(),
        .m_axi_arprot(),
        .m_axi_arregion(),
        .m_axi_arqos(),
        .m_axi_arvalid(ddr_axi_arvalid),
        .m_axi_arready(ddr_axi_arready),
        .m_axi_rid(ddr_axi_rid),
        .m_axi_rdata(ddr_axi_rdata),
        .m_axi_rresp(ddr_axi_rresp),
        .m_axi_rlast(ddr_axi_rlast),
        .m_axi_rvalid(ddr_axi_rvalid),
        .m_axi_rready(ddr_axi_rready)
);

// Misc wires
wire        init_calib_complete;
wire        mmcm_locked;
wire        app_sr_active;
wire        app_ref_ack;
wire        app_zq_ack;
wire        app_sr_req;
wire        app_ref_req;
wire        app_zq_req;
wire        w_sys_reset;
wire [11:0] w_device_temp;

wire ddr_axi_clk;

// Convert from active low to active high reset,
// *and* hold the system in reset until the memory comes up.
reg ddr_rst;
initial ddr_rst = 1'b1;
always @(posedge ddr_axi_clk)
        ddr_rst <= w_sys_reset || (!init_calib_complete) || (!mmcm_locked);

mig_axis mig_sdram (
        // DDR Pins
        .ddr3_ck_p(ddr_ck_p_o),
        .ddr3_ck_n(ddr_ck_n_o),
        .ddr3_reset_n(ddr_reset_n_o),
        .ddr3_cke(ddr_cke_o),
        .ddr3_cs_n(ddr_cs_n_o),
        .ddr3_ras_n(ddr_ras_n_o),
        .ddr3_we_n(ddr_we_n_o),
        .ddr3_cas_n(ddr_cas_n_o),
        .ddr3_ba(ddr_ba_o),
        .ddr3_addr(ddr_addr_o),
        .ddr3_odt(ddr_odt_o),
        .ddr3_dqs_p(ddr_dqs_p_io),
        .ddr3_dqs_n(ddr_dqs_n_io),
        .ddr3_dq(ddr_data_io),
        .ddr3_dm(ddr_dm_o),

        // Misc
        .sys_clk_i(clk100_i),
        .clk_ref_i(clk200_i),
        .ui_clk(clkOut_o),
        .ui_clk_sync_rst(w_sys_reset),
        .mmcm_locked(mmcm_locked),
        .aresetn(1'b1),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0),
        .app_sr_active(app_sr_active),
        .app_ref_ack(app_ref_ack),
        .app_zq_ack(app_zq_ack),
        .init_calib_complete(init_calib_complete),
        .sys_rst(reset_i),
        .device_temp(w_device_temp),

        // AXI
        // Write Address
        .s_axi_awid(ddr_axi_awid),
        .s_axi_awaddr(ddr_axi_awaddr[27:0]),
        .s_axi_awlen(ddr_axi_awlen),
        .s_axi_awsize(3'b010), // 4-byte burst size
        .s_axi_awburst(2'b01), // Incremental burst
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'h2),
        .s_axi_awprot(3'b010),
        .s_axi_awqos(4'h0),
        .s_axi_awvalid(ddr_axi_awvalid),
        .s_axi_awready(ddr_axi_awready),
        // Write Data
        .s_axi_wready(ddr_axi_wready),
        .s_axi_wdata(ddr_axi_wdata),
        .s_axi_wstrb(ddr_axi_wstrb),
        .s_axi_wlast(ddr_axi_wlast),
        .s_axi_wvalid(ddr_axi_wvalid),
        // Write Response
        .s_axi_bready(ddr_axi_bready),
        .s_axi_bid(ddr_axi_bid),
        .s_axi_bresp(ddr_axi_bresp),
        .s_axi_bvalid(ddr_axi_bvalid),
        // Read Address
        .s_axi_arid(ddr_axi_arid),
        .s_axi_araddr(ddr_axi_araddr_i[27:0]),
        .s_axi_arlen(ddr_axi_arlen),
        .s_axi_arsize(3'b010), // 4-byte burst size
        .s_axi_arburst(2'b01), // Incremental burst
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'h2),
        .s_axi_arprot(3'b010),
        .s_axi_arqos(4'h0),
        .s_axi_arvalid(ddr_axi_arvalid),
        .s_axi_arready(ddr_axi_arready),
        // Read Data
        .s_axi_rready(ddr_axi_rready),
        .s_axi_rid(ddr_axi_rid),
        .s_axi_rdata(ddr_axi_rdata),
        .s_axi_rresp(ddr_axi_rresp),
        .s_axi_rlast(ddr_axi_rlast),
        .s_axi_rvalid(ddr_axi_rvalid)
);

endmodule

