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
        #5  ptw_rden <= 1'b1;
        #10 ptw_rden <= 1'b0;
        #200 $finish;
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

wire [19:0]  ptw_vpn = 20'h12345;
reg          ptw_rden = 1'b0;
wire [1:0]   ptw_priv = 2'b00;
wire         ptw_instr = 1'b0;
wire         ptw_write = 1'b0;
wire         ptw_mxr = 1'b0;
wire         ptw_sum = 1'b1;
wire [21:0]  ptw_ptppn = 22'h080200;
wire [21:0]  ptw_ppn;
wire [8:0]   ptw_flags;
wire         ptw_valid;
wire         ptw_fault;

wire [31:0]  DMemAddr;
wire         DMemRden;
wire [63:0]  DMemWData;
wire [7:0]   DMemWren;
reg  [63:0]  DMemRData = 63'b0;
reg          DMemValidReady = 1'b0;

always @(posedge clk) begin
        if (DMemRden) begin
                if (DMemAddr == 32'h80200120) begin
                        DMemRData <= {2{32'b0, 22'h080300, 10'b0011010001}};
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

PTW ptw(
        .clk_i(clk),
        .reset_i(rst),

        .i_vpn_i(ptw_vpn),
        .i_rden_i(ptw_rden),
        .i_priv_i(ptw_priv),
        .i_instr_i(ptw_instr),
        .i_write_i(ptw_write),
        .i_mxr_i(ptw_mxr),
        .i_sum_i(ptw_sum),
        .i_ptppn_i(ptw_ptppn),
        .i_ppn_o(ptw_ppn),
        .i_flags_o(ptw_flags),
        .i_valid_o(ptw_valid),
        .i_fault_o(ptw_fault),

        .d_vpn_i(20'b0),
        .d_rden_i(1'b0),
        .d_priv_i(2'b0),
        .d_instr_i(1'b0),
        .d_write_i(1'b0),
        .d_mxr_i(1'b0),
        .d_sum_i(1'b0),
        .d_ptppn_i(22'b0),
        .d_ppn_o(),
        .d_flags_o(),
        .d_valid_o(),
        .d_fault_o(),

        .DMemAddr_o(DMemAddr),
        .DMemRden_o(DMemRden),
        .DMemWData_o(DMemWData),
        .DMemWren_o(DMemWren),
        .DMemRData_i(DMemRData),
        .DMemValidReady_i(DMemValidReady)
);
endmodule

