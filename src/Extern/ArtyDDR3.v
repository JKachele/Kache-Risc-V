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
        input  wire        reset_i,
        output wire        clkOut_o,
        output wire        rstOut_o,
        // AXI4 Interface
        input  wire [31:0] s_axi_awaddr_i,
        input  wire [ 7:0] s_axi_awlen_i,
        input  wire [ 3:0] s_axi_awid_i,
        input  wire        s_axi_awvalid_i,
        output wire        s_axi_awready_o,
        input  wire [31:0] s_axi_wdata_i,
        input  wire [ 3:0] s_axi_wstrb_i,
        input  wire        s_axi_wlast_i,
        input  wire        s_axi_wvalid_i,
        output wire        s_axi_wready_o,
        output wire [ 1:0] s_axi_bresp_o,
        output wire [ 3:0] s_axi_bid_o,
        output wire        s_axi_bvalid_o,
        input  wire        s_axi_bready_i,
        input  wire [31:0] s_axi_araddr_i,
        input  wire [ 7:0] s_axi_arlen_i,
        input  wire [ 3:0] s_axi_arid_i,
        input  wire        s_axi_arvalid_i,
        output wire        s_axi_arready_o,
        output wire [31:0] s_axi_rdata_o,
        output wire [ 1:0] s_axi_rresp_o,
        output wire        s_axi_rlast_o,
        output wire [ 3:0] s_axi_rid_o,
        output wire        s_axi_rvalid_o,
        input  wire        s_axi_rready_i,

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

// Convert from active low to active high reset,
// *and* hold the system in reset until the memory comes up.
reg sys_rst_o;
initial sys_rst_o = 1'b1;
always @(posedge clkOut_o)
        sys_rst_o <= w_sys_reset || (!init_calib_complete) || (!mmcm_locked);

assign rstOut_o = sys_rst_o;

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
        .s_axi_awid(s_axi_awid_i),
        .s_axi_awaddr(s_axi_awaddr_i[27:0]),
        .s_axi_awlen(s_axi_awlen_i),
        .s_axi_awsize(3'b010), // 4-byte burst size
        .s_axi_awburst(2'b01), // Incremental burst
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'h2),
        .s_axi_awprot(3'b010),
        .s_axi_awqos(4'h0),
        .s_axi_awvalid(s_axi_awvalid_i),
        .s_axi_awready(s_axi_awready_o),
        // Write Data
        .s_axi_wready(s_axi_wready_o),
        .s_axi_wdata(s_axi_wdata_i),
        .s_axi_wstrb(s_axi_wstrb_i),
        .s_axi_wlast(s_axi_wlast_i),
        .s_axi_wvalid(s_axi_wvalid_i),
        // Write Response
        .s_axi_bready(s_axi_bready_i),
        .s_axi_bid(s_axi_bid_o),
        .s_axi_bresp(s_axi_bresp_o),
        .s_axi_bvalid(s_axi_bvalid_o),
        // Read Address
        .s_axi_arid(s_axi_arid_i),
        .s_axi_araddr(s_axi_araddr_i[27:0]),
        .s_axi_arlen(s_axi_arlen_i),
        .s_axi_arsize(3'b010), // 4-byte burst size
        .s_axi_arburst(2'b01), // Incremental burst
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'h2),
        .s_axi_arprot(3'b010),
        .s_axi_arqos(4'h0),
        .s_axi_arvalid(s_axi_arvalid_i),
        .s_axi_arready(s_axi_arready_o),
        // Read Data
        .s_axi_rready(s_axi_rready_i),
        .s_axi_rid(s_axi_rid_o),
        .s_axi_rdata(s_axi_rdata_o),
        .s_axi_rresp(s_axi_rresp_o),
        .s_axi_rlast(s_axi_rlast_o),
        .s_axi_rvalid(s_axi_rvalid_o)
);

endmodule

