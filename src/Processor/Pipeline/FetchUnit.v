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
        input  wire        F_stall_i,
        input  wire        D_flush_i,
        input  wire        D_predictPC_i,
        input  wire [31:0] D_PCprediction_i,
        input  wire        EM_correctPC_i,
        input  wire [31:0] EM_PCcorrection_i,
        // Memory Interface
        output wire [31:0] IMemAddr_o,
        input  wire [63:0] IMemData_i,
        output wire        IMemStrb_o,
        // Decode Unit Interface
        output reg  [31:0] FD_PC_o,
        output wire [63:0] FD_instr_o,
        output wire        FD_isRV32C_o,
        output reg         FD_nop_o
);

reg [31:0] PC;

wire [31:0] F_PC =
        D_predictPC_i  ? D_PCprediction_i  :
        EM_correctPC_i ? EM_PCcorrection_i :
                             PC + (FD_isRV32C_o ? 2 : 4);

assign IMemAddr_o = F_PC;
assign FD_instr_o = IMemData_i;
assign IMemStrb_o = ~F_stall_i;

// The 2 LSBs of uncompressed instructions are always 2'b11
// wire F_isCompressed = F_PC[1] ? ~(&IMemData_i[17:16]) : ~(&IMemData_i[1:0]);
assign FD_isRV32C_o = PC[1] ? ~(&FD_instr_o[17:16]) : ~(&FD_instr_o[1:0]);

always @(posedge clk_i) begin
        if (!F_stall_i) begin
                // FD_instr_o <= IMemData_i;
                FD_PC_o <= F_PC;
                // FD_isRV32C_o <= F_isCompressed;
                // Add 2 for compressed instructions and 4 for uncompressed
                PC <= F_PC; // + (F_isCompressed ? 2 : 4);
        end

        FD_nop_o <= D_flush_i | reset_i;

        if (reset_i) begin
                PC <= rvec_i - 32'h2;
        end

end

endmodule

