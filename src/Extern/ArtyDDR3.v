/*************************************************
 *File----------ArtyDDR3.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jun 18, 2026 13:42:39 UTC
 ************************************************/

module ArtyDDR3 (
        input  wire         clk100_i,
        input  wire         clk200_i,
        input  wire         clk25_i,
        input  wire         reset_i,
        output wire         clkOut_o,
        output wire         rstOut_o,

        // User Interface
        input  wire [31:0]  mem_addr,
        input  wire         mem_rd,
        input  wire         mem_wr,
        input  wire [255:0] mem_wdata,
        input  wire [7:0]   mem_wmask,
        output reg  [255:0] mem_rdata,
        output reg          mem_rdy,

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
wire [27:0]  mig_addr;
wire [2:0]   mig_cmd;
wire         mig_en;
wire [127:0] mig_wdf_data;
wire         mig_wdf_end;
wire [15:0]  mig_wdf_mask;
wire         mig_wdf_wren;
wire [127:0] mig_rd_data;
wire         mig_rd_data_end;
wire         mig_rd_data_valid;
wire         mig_rdy;
wire         mig_wdf_rdy;
wire         ui_clk;
wire         ui_reset;
wire         init_calib_complete;
wire [11:0]  mig_device_temp;
/*-------------------------------- Clock Domain Crosser --------------------------------*/
// // SOC -> MIG FIFO
// // {addr, wdata, wmask, wr}
// fifo_gen_0 fifo_in (
//         .rst(reset_i),
//         .wr_clk(clk25_i),
//         .rd_clk(ui_clk),
//         .din({mem_addr, mem_wdata, mem_wmask, mem_wr}),
//         .wr_en(mem_rd | mem_wr),
//         .rd_en(),
//         .dout(),
//         .full(),
//         .empty()
// );
// reg [296:0] fifo_in [0:15];
// reg  [3:0] fifo_in_wrptr_bin;
// reg  [3:0] fifo_in_rdptr_bin;
// wire [3:0] fifo_in_wrptr_gray = bin_to_gray(fifo_in_wrptr_bin);
// wire [3:0] fifo_in_rdptr_gray = bin_to_gray(fifo_in_rdptr_bin);
// wire fifo_in_empty = (fifo_in_wrptr_gray == fifo_in_rdptr_gray);
// 
// // MIG -> SOC FIFO
// // {rdata, rdy}
// reg [256:0] fifo_out [0:15];
// reg  [3:0] fifo_out_wrptr_bin;
// reg  [3:0] fifo_out_rdptr_bin;
// wire [3:0] fifo_out_wrptr_gray = bin_to_gray(fifo_out_wrptr_bin);
// wire [3:0] fifo_out_rdptr_gray = bin_to_gray(fifo_out_rdptr_bin);
// wire fifo_out_empty = (fifo_out_wrptr_gray == fifo_out_rdptr_gray);
// 
// // SOC CLock Domain
// always @(posedge clk25_i) begin
// end

/*-------------------------------- DDR3 MIG --------------------------------*/
mig_7series_0 mig (
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),

        // Single-ended system clock
        .sys_clk_i(clk200_i),

        // user interface signals
        .app_addr(mig_addr),
        .app_cmd(mig_cmd),
        .app_en(mig_en),
        .app_wdf_data(mig_wdf_data),
        .app_wdf_end(mig_wdf_end),
        .app_wdf_mask(mig_wdf_mask),
        .app_wdf_wren(mig_wdf_wren),
        .app_rd_data(mig_rd_data),
        .app_rd_data_end(mig_rd_data_end),
        .app_rd_data_valid(mig_rd_data_valid),
        .app_rdy(mig_rdy),
        .app_wdf_rdy(mig_wdf_rdy),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0),
        .app_sr_active(),
        .app_ref_ack(),
        .app_zq_ack(),
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_reset),
        .init_calib_complete(init_calib_complete),
        .device_temp(mig_device_temp),
        .sys_rst(reset_i)
);

endmodule
