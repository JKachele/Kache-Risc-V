/*************************************************
 *File----------FetchUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 15:40:10 UTC
 ************************************************/

module FetchUnit (
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire [31:0] rvec_i,
        // Pipeline Control Signals
        output wire        F_busy_o,
        input  wire        F_stall_i,
        input  wire        D_flush_i,
        input  wire        D_predictPC_i,
        input  wire [31:0] D_PCprediction_i,
        input  wire        E_correctPC_i,
        input  wire [31:0] E_PCcorrection_i,
        // Cache Interface
        output wire        ICacheStrb_o,
        output wire        ICacheCancel_o,
        output wire [31:0] ICacheAddr_o,
        input  wire [31:0] ICacheData_i,
        input  wire        ICacheValid_i,
        input  wire        ICacheCmp_i,
        // Decode Unit Interface
        output reg  [31:0] FD_PC_o,
        output wire [31:0] FD_instr_o,
        output reg         FD_isRV32C_o,
        output reg         FD_nop_o
);

reg [31:0] PC;

wire [31:0] PC_Next =
        E_correctPC_i   ? E_PCcorrection_i :
        D_predictPC_i   ? D_PCprediction_i :
        F_isSplitInstr  ? PC + 2           :
        ICacheCmp_i     ? PC + 2           : PC + 4;

assign ICacheAddr_o = PC;
assign ICacheCancel_o = D_flush_i;
assign ICacheStrb_o = ~F_stall_i & ~reset_i;

// Must perform 2 fetches if instruction isn't compressed and straddles 2 cache lines
/*verilator public_flat_rw_on*/
wire       ICacheSplit = !D_flush_i && !ICacheCmp_i && PC[4:1] == 4'b1111;
reg        F_isSplitInstr;
reg        FD_isSplitInstr;
reg [15:0] FD_instrPart;
reg [31:0] FD_instrHold; // Hold previous instruction while fetching 2nd half
/*verilator public_off*/

assign F_busy_o = ~ICacheValid_i | ICacheSplit;
assign FD_instr_o = F_isSplitInstr  ? FD_instrHold :
                    FD_isSplitInstr ? {ICacheData_i[15:0], FD_instrPart} : ICacheData_i;

always @(posedge clk_i) begin
        if (reset_i) begin
                PC <= rvec_i;
                FD_PC_o <= rvec_i;
                FD_nop_o <= 1'b1;
                FD_isRV32C_o <= 1'b0;
        end else if (!F_stall_i && ICacheValid_i) begin
                F_isSplitInstr <= ICacheSplit;
                FD_isSplitInstr <= F_isSplitInstr;
                if (F_isSplitInstr)
                        FD_instrPart <= ICacheData_i[15:0];
                if (ICacheSplit) begin
                        PC <= PC + 2;
                        FD_instrHold <= ICacheData_i;
                end else begin
                        FD_PC_o <= F_isSplitInstr ? PC - 2 : PC;
                        FD_nop_o <= D_predictPC_i | D_flush_i;
                        FD_isRV32C_o <= F_isSplitInstr ? 1'b0 : ICacheCmp_i;
                        PC <= PC_Next;
                end
        end
end

endmodule

