/*************************************************
 *File----------ICache.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday May 13, 2026 20:44:47 UTC
 ************************************************/

`define TAG 31:13
`define INDEX 12:3
`define OFFSET 2:0

module ICache #(
)(
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire [31:0] addr_i,
        input  wire        rden_i,
        output wire        hitMiss_o,
        output wire [63:0] data_o,

        output wire [31:0] mAddr_o,
        output wire        mRden_o,
        input  wire [63:0] mData_i,
        input  wire        mBusy_i
);
/*****************************************************************
 * 2-Way Set Associative Read-Only Cache
 * LRU Replacement Policy
 * 16KB: 64-bit line size, 2 Ways, 1024 Sets
 * Address Mapping:
 * 31       13 12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *---------------------------* *------*
 *     Tag               Index                Offset
 *
 *****************************************************************/
localparam int NSETS        = 1024;
localparam int TAG_WIDTH    = 19;
localparam int INDEX_WIDTH  = 10;
localparam int OFFSET_WIDTH = 3;

// Way 0 cache data
reg [63:0]          mem0   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag0   [0:NSETS-1];
reg                 valid0 [0:NSETS-1];
reg                 lru0   [0:NSETS-1];

// Way 1 cache data
reg [63:0]          mem1   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag1   [0:NSETS-1];
reg                 valid1 [0:NSETS-1];
reg                 lru1   [0:NSETS-1];

reg        C_hitMiss_r = 1'b0;
reg [63:0] C_data0     = 64'b0;
reg [63:0] C_data1     = 64'b0;
wire       C_hit0 = (valid0[addr_i[`INDEX]] && (tag0[addr_i[`INDEX]] == addr_i[`TAG]));
wire       C_hit1 = (valid1[addr_i[`INDEX]] && (tag1[addr_i[`INDEX]] == addr_i[`TAG]));

assign hitMiss_o = C_hitMiss;
assign data_o    = C_hit0 ? C_data0 : C_data1;
assign mAddr_o   = addr_i;
assign mRden_o   = ~(C_hit0 || C_hit1);

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE = 1'b0;
localparam MISS = 1'b1;

reg C_curState = IDLE;

always @(posedge clk_i) begin
        case (C_curState)
                IDLE: begin
                        // Do nothing
                        if (~rden_i) begin
                                C_hitMiss <= 1'b1;
                        end
                        // Check Way 0
                        else if (C_hit0) begin
                                C_data0 <= mem0[addr_i[`INDEX]];
                                lru0[addr_i[`INDEX]] <= 1'b0;
                                lru1[addr_i[`INDEX]] <= 1'b1;
                                C_hitMiss <= 1'b1;
                        end
                        // Check Way 1
                        else if (C_hit1) begin
                                C_data1 <= mem1[addr_i[`INDEX]];
                                lru0[addr_i[`INDEX]] <= 1'b1;
                                lru1[addr_i[`INDEX]] <= 1'b0;
                                C_hitMiss <= 1'b1;
                        end
                        // Cache Miss
                        else begin
                                C_curState <= MISS;
                                C_hitMiss <= 1'b0;
                        end
                end

                MISS: begin
                        // Check for invalid ways
                        if (~valid0[addr_i[`INDEX]]) begin
                        end
                        else if (~valid0[addr_i[`INDEX]]) begin
                        end
                end

                default: C_curState = IDLE;
        endcase
end

endmodule

