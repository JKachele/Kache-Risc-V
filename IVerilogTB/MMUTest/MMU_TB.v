/*************************************************
 *File----------MMU_TB.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Jul 28, 2026 14:38:39 EDT
 ************************************************/

module MMU_TB;
reg  clk;
reg  rst;

initial
begin
        rst <= 1'b1;
        #10 rst <= 1'b0;
        #5  i_rden <= 1'b1;
            d_rden <= 1'b1;
        #10 i_rden <= 1'b0;
            d_rden <= 1'b0;
        #500 $finish;
end

initial
begin
        clk <= 1'b1;
        while (1) begin
                #5 clk <= ~clk;
        end
end

initial
begin
        $dumpfile("mmuTB.vcd");
        $dumpvars(0, MMU_TB);
end

wire [19:0] i_vpn = 20'h12345;
wire [8:0]  i_asid = 9'b0;
reg         i_rden = 1'b0;
wire        i_flush = 1'b0;
wire [1:0]  i_priv = 2'b00;
wire        i_instr = 1'b0;
wire        i_write = 1'b0;
wire        i_mxr = 1'b0;
wire        i_sum = 1'b1;
wire        i_vmEnable = 1'b1;
wire [21:0] i_ptppn = 22'h080200;
wire        i_cancel = 1'b0;
wire [21:0] i_ppn;
wire        i_valid;

wire [19:0] d_vpn = 20'h12345;
wire [8:0]  d_asid = 9'b0;
reg         d_rden = 1'b0;
wire        d_flush = 1'b0;
wire [1:0]  d_priv = 2'b00;
wire        d_instr = 1'b0;
wire        d_write = 1'b0;
wire        d_mxr = 1'b0;
wire        d_sum = 1'b1;
wire        d_vmEnable = 1'b1;
wire [21:0] d_ptppn = 22'h080200;
wire        d_cancel = 1'b0;
wire [21:0] d_ppn;
wire        d_valid;

wire [31:0]  DMemAddr;
wire         DMemRden;
wire [63:0]  DMemWData;
wire [7:0]   DMemWren;
reg  [63:0]  DMemRData = 63'b0;
reg          DMemValidReady = 1'b0;

always @(posedge clk) begin
        if (DMemRden) begin
                if (DMemAddr == 32'h80200120) begin
                        DMemRData <= {2{22'h080300, 10'b0011010001}};
                        DMemValidReady <= 1'b1;
                end else if (DMemAddr == 32'h80300D14) begin
                        DMemRData <= {2{22'h156487, 10'b0011011111}};
                        DMemValidReady <= 1'b1;
                end else begin
                        DMemRData <= 64'b0;
                        DMemValidReady <= 1'b0;
                end
        end else begin
                DMemValidReady <= 1'b0;
        end
end

MMU mmu(
        .clk_i(clk),
        .reset_i(rst),

        .i_vpn_i(i_vpn),
        .i_asid_i(i_asid),
        .i_rden_i(i_rden),
        .i_flush_i(i_flush),
        .i_priv_i(i_priv),
        .i_instr_i(i_instr),
        .i_write_i(i_write),
        .i_mxr_i(i_mxr),
        .i_sum_i(i_sum),
        .i_vmEnable_i(i_vmEnable),
        .i_ptppn_i(i_ptppn),
        .i_cancel_i(i_cancel),
        .i_ppn_o(i_ppn),
        .i_valid_o(i_valid),

        .d_vpn_i(d_vpn),
        .d_asid_i(d_asid),
        .d_rden_i(d_rden),
        .d_flush_i(d_flush),
        .d_priv_i(d_priv),
        .d_instr_i(d_instr),
        .d_write_i(d_write),
        .d_mxr_i(d_mxr),
        .d_sum_i(d_sum),
        .d_vmEnable_i(d_vmEnable),
        .d_ptppn_i(d_ptppn),
        .d_cancel_i(d_cancel),
        .d_ppn_o(d_ppn),
        .d_valid_o(d_valid),

        .DMemAddr_o(DMemAddr),
        .DMemRden_o(DMemRden),
        .DMemWData_o(DMemWData),
        .DMemWren_o(DMemWren),
        .DMemRData_i(DMemRData),
        .DMemValidReady_i(DMemValidReady)
);

// PTW ptw(
//         .clk_i(clk),
//         .reset_i(rst),
//
//         .i_vpn_i(ptw_vpn),
//         .i_rden_i(ptw_rden),
//         .i_priv_i(ptw_priv),
//         .i_instr_i(ptw_instr),
//         .i_write_i(ptw_write),
//         .i_mxr_i(ptw_mxr),
//         .i_sum_i(ptw_sum),
//         .i_ptppn_i(ptw_ptppn),
//         .i_ppn_o(ptw_ppn),
//         .i_flags_o(ptw_flags),
//         .i_valid_o(ptw_valid),
//         .i_fault_o(ptw_fault),
//
//         .d_vpn_i(20'b0),
//         .d_rden_i(1'b0),
//         .d_priv_i(2'b0),
//         .d_instr_i(1'b0),
//         .d_write_i(1'b0),
//         .d_mxr_i(1'b0),
//         .d_sum_i(1'b0),
//         .d_ptppn_i(22'b0),
//         .d_ppn_o(),
//         .d_flags_o(),
//         .d_valid_o(),
//         .d_fault_o(),
//
//         .DMemAddr_o(DMemAddr),
//         .DMemRden_o(DMemRden),
//         .DMemWData_o(DMemWData),
//         .DMemWren_o(DMemWren),
//         .DMemRData_i(DMemRData),
//         .DMemValidReady_i(DMemValidReady)
// );

endmodule

