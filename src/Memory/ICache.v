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
        input  wire        cancel_i,
        output wire        valid_o,
        output wire [31:0] data_o,

        output wire [31:0] mAddr_o,
        output wire        mRden_o,
        input  wire [63:0] mData_i,
        input  wire        mValid_i
);
/*****************************************************************
 * 2-Way Set Associative Read-Only Cache
 * LRU Replacement Policy
 * 16KB: 64-bit line size, 2 Ways, 1024 Sets
 * Address Mapping:
 * 31       13 12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *--------------------------*  *-----*
 *     Tag              Index                Offset
 *
 *****************************************************************/
localparam int NSETS        = 1024;
localparam int TAG_WIDTH    = 19;
localparam int INDEX_WIDTH  = 10;
localparam int OFFSET_WIDTH = 3;

wire [18:0] tag    = addr_i[`TAG];
wire [9:0]  index  = addr_i[`INDEX];
wire [2:0]  offset = addr_i[`OFFSET];

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

reg         C_dataWay;
reg  [63:0] C_data0;
reg  [63:0] C_data1;
wire        C_hit0 = (valid0[index] && (tag0[index] == tag));
wire        C_hit1 = (valid1[index] && (tag1[index] == tag));
wire        C_hit  = (C_hit0 | C_hit1);

wire [31:0] C_offsetData0 = offset[2] ? C_data0[31:0] : C_data0[63:32];
wire [31:0] C_offsetData1 = offset[2] ? C_data1[31:0] : C_data1[63:32];

assign valid_o   = cancel_i | (C_curState == IDLE & C_hit);
assign data_o    = C_dataWay ? C_offsetData1 : C_offsetData0;
assign mAddr_o   = {tag, index, 3'b0};
assign mRden_o   = C_curState == IDLE & ~C_hit & rden_i & ~cancel_i;

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE = 1'b0;
localparam MISS = 1'b1;

reg C_curState = IDLE;

always @(posedge clk_i) begin
        case (C_curState)
                IDLE: begin
                        if (~rden_i | cancel_i) begin
                                // Do nothing
                        end
                        // Check Way 0
                        else if (C_hit0) begin
                                C_data0 <= mem0[index];
                                C_dataWay <= 1'b0;
                                lru0[index] <= 1'b0;
                                lru1[index] <= 1'b1;
                        end
                        // Check Way 1
                        else if (C_hit1) begin
                                C_data1 <= mem1[index];
                                C_dataWay <= 1'b1;
                                lru0[index] <= 1'b1;
                                lru1[index] <= 1'b0;
                        end
                        // Cache Miss
                        else begin
                                C_curState <= MISS;
                        end
                end

                MISS: begin
                        if (mValid_i) begin
                                // Check for invalid ways
                                if (~valid0[index]) begin
                                        mem0[index] <= mData_i;
                                        tag0[index] <= tag;
                                        valid0[index] <= 1'b1;
                                end
                                else if (~valid1[index]) begin
                                        mem1[index] <= mData_i;
                                        tag1[index] <= tag;
                                        valid1[index] <= 1'b1;
                                end
                                // Way 0 is Least Recently Used
                                else if (lru0[index] == 1'b1) begin
                                        mem0[index] <= mData_i;
                                        tag0[index] <= tag;
                                        valid0[index] <= 1'b1;
                                end
                                // Way 1 is Least Recently Used
                                else if (lru1[index] == 1'b1) begin
                                        mem1[index] <= mData_i;
                                        tag1[index] <= tag;
                                        valid1[index] <= 1'b1;
                                end
                                C_curState <= IDLE;
                        end
                end

                default: C_curState = IDLE;
        endcase
end

endmodule

