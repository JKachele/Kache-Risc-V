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
        output reg         ICacheStrb_o,
        output wire        ICacheCancel_o,
        output wire [31:0] ICacheAddr_o,
        input  wire [31:0] ICacheData_i,
        input  wire        ICacheValid_i,
        // Decode Unit Interface
        output wire [31:0] FD_PC_o,
        output wire [31:0] FD_instr_o,
        output wire        FD_isRV32C_o,
        output reg         FD_nop_o
);

reg [31:0] PC;

wire [31:0] PC_Next =
        E_correctPC_i ? E_PCcorrection_i :
        D_predictPC_i  ? D_PCprediction_i  :
                             PC + 4;

assign F_busy_o = ~ICacheValid_i;
assign ICacheAddr_o = PC;
assign FD_instr_o = ICacheData_i;
assign ICacheCancel_o = D_flush_i;
assign ICacheStrb_o = ~F_stall_i & ~reset_i;

// The 2 LSBs of uncompressed instructions are always 2'b11
// wire F_isCompressed = F_PC[1] ? ~(&IMemData_i[17:16]) : ~(&IMemData_i[1:0]);
// assign FD_isRV32C_o = PC[1] ? ~(&FD_instr_o[17:16]) : ~(&FD_instr_o[1:0]);
assign FD_isRV32C_o = ~(&FD_instr_o[1:0]);

always @(posedge clk_i) begin
        if (reset_i) begin
                PC <= rvec_i;
                // ICacheStrb_o <= 1'b1;
                FD_PC_o <= rvec_i;
                FD_nop_o <= 1'b1;
        end else if (!F_stall_i) begin
                // ICacheStrb_o <= 1'b1;
                if (ICacheValid_i) begin
                        FD_PC_o <= PC;
                        FD_nop_o <= D_predictPC_i | D_flush_i;
                        PC <= PC_Next;
                end
        // end else begin
        //         ICacheStrb_o <= 1'b0;
        end

        // if (!F_stall_i) begin
        //         // FD_instr_o <= IMemData_i;
        //         FD_PC_o <= PC_Next;
        //         // FD_isRV32C_o <= F_isCompressed;
        //         // Add 2 for compressed instructions and 4 for uncompressed
        //         PC <= PC_Next; // + (F_isCompressed ? 2 : 4);
        // end
        // FD_nop_o <= D_flush_i | reset_i;
        // if (reset_i) begin
        //         PC <= rvec_i - 32'h4;
        // end

end

endmodule

