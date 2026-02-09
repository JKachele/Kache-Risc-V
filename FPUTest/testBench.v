/*************************************************
 *File----------testBench.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jan 22, 2026 19:30:55 UTC
 ************************************************/

module testBench (
        input wire clk,
        input wire rst
);

reg [31:0] input_a [0:999];
reg [31:0] input_b [0:999];
reg [31:0] input_c [0:999];

initial begin
        $readmemh("stim_a",input_a);
        $readmemh("stim_b",input_b);
        $readmemh("stim_c",input_c);
end

integer outputFile;
initial begin
        outputFile = $fopen("resp_z", "w");
        $fclose(outputFile);
end

reg [31:0] instr = 32'h00000013;
reg [9:0] index;
reg [63:0] rs1;
reg [63:0] rs2;
reg [63:0] rs3;
reg [31:0] out;

wire busy;
wire [63:0] fpuOut;
FPU fpu(
        .clk_i(clk),
        .reset_i(rst),
        .fpuEnable_i(1'b1),
        .instr_i(instr),
        .rs1_i(rs1),
        .rs2_i(rs2),
        .rs3_i(rs3),
        .rm_i(3'b000),
        .fflags_o(),
        .busy_o(busy),
        .fpuOut_o(fpuOut)
);

localparam NOP = 32'h00000013;
localparam FLOP = 32'h2a001053;

reg [1:0] state;
always @(posedge clk) begin
        if (rst == 1'b1) begin
                state <= 0;
                index <= 0;
                instr <= NOP;
        end
        else begin
                case(state)
                        0: begin
                                if (input_a[index][0] === 1'bx) begin
                                        $finish;
                                end else begin
                                        rs1 <= {{32{1'b0}}, input_a[index]};
                                        rs2 <= {{32{1'b0}}, input_b[index]};
                                        rs3 <= {{32{1'b0}}, input_c[index]};
                                        instr <= FLOP;
                                        state <= 1;
                                end
                        end
                        1: begin // Wait
                                if (!busy) begin
                                        out <= fpuOut[31:0];
                                        instr <= NOP;
                                        state <= 2;
                                end
                        end
                        2: begin
                                if (out[0] !== 1'bx) begin
                                `ifdef SINGLE
                                        $display("%x", out);
                                `endif
                                        outputFile = $fopen("resp_z", "a");
                                        $fdisplayh(outputFile, out);
                                        $fclose(outputFile);
                                end
                                index <= index + 1;
                                if (index == 1000)
                                        $finish;
                                state <= 0;
                        end
                endcase
        end
end

endmodule

