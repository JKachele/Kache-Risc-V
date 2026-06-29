/*************************************************
 *File----------ICache.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday May 13, 2026 20:44:47 UTC
 ************************************************/

module ICache #(
)(
        input  wire         clk_i,
        input  wire         reset_i,

        input  wire [31:0]  addr_i,
        input  wire         rden_i,
        input  wire         cancel_i,
        output wire [31:0]  data_o,
        output wire         valid_o,
        output wire         cmp_o,

        output wire [31:0]  mAddr_o,
        output wire         mRden_o,
        input  wire [255:0] mData_i,
        input  wire         mValid_i
);
/*****************************************************************
 * 2-Way Set Associative Read-Only Cache
 * LRU Replacement Policy
 * 32KB: 32-byte line size, 2 Ways, 512 Sets
 * Address Mapping:
 * 31       14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *-----------------------*  *-----------*
 *     Tag              Index                Offset
 *
 *****************************************************************/
localparam NSETS        = 512;
localparam TAG_WIDTH    = 18;
localparam INDEX_WIDTH  = 9;
localparam OFFSET_WIDTH = 5;

`define IC_TAG 31:14
`define IC_INDEX 13:5
`define IC_OFFSET 4:0

wire [17:0] tag    = addr_i[`IC_TAG];
wire [8:0]  index  = addr_i[`IC_INDEX];
wire [4:0]  offset = addr_i[`IC_OFFSET];

// Way 0 cache data
reg [255:0]         mem0   [0:NSETS-1];
reg [15:0]          cmp0   [0:NSETS-1]; // If a 16-bit block is a compressed instruction
reg [TAG_WIDTH-1:0] tag0   [0:NSETS-1];
reg                 valid0 [0:NSETS-1];

// Way 1 cache data
reg [255:0]         mem1   [0:NSETS-1];
reg [15:0]          cmp1   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag1   [0:NSETS-1];
reg                 valid1 [0:NSETS-1];

reg                 lru    [0:NSETS-1];

reg  [4:0]   C_offset;
reg          C_dataWay;
reg  [255:0] C_data0;
reg  [255:0] C_data1;
wire [255:0] C_data = C_dataWay ? C_data1 : C_data0;
wire         C_hit0 = (valid0[index] && (tag0[index] == tag));
wire         C_hit1 = (valid1[index] && (tag1[index] == tag));
wire         C_hit  = (C_hit0 | C_hit1);

reg [31:0] C_offsetData;
always @(*) begin
        case (C_offset[4:1])
                4'b0000: C_offsetData = C_data[31:0];
                4'b0001: C_offsetData = C_data[47:16];
                4'b0010: C_offsetData = C_data[63:32];
                4'b0011: C_offsetData = C_data[79:48];
                4'b0100: C_offsetData = C_data[95:64];
                4'b0101: C_offsetData = C_data[111:80];
                4'b0110: C_offsetData = C_data[127:96];
                4'b0111: C_offsetData = C_data[143:112];
                4'b1000: C_offsetData = C_data[159:128];
                4'b1001: C_offsetData = C_data[175:144];
                4'b1010: C_offsetData = C_data[191:160];
                4'b1011: C_offsetData = C_data[207:176];
                4'b1100: C_offsetData = C_data[223:192];
                4'b1101: C_offsetData = C_data[239:208];
                4'b1110: C_offsetData = C_data[255:224];
                4'b1111: C_offsetData = {16'b0, C_data[255:240]};
        endcase
end

assign valid_o   = cancel_i | (C_curState == IDLE & C_hit);
assign data_o    = C_offsetData;
assign cmp_o     = C_hit0 ? cmp0[index][offset[4:1]] : cmp1[index][offset[4:1]];
assign mAddr_o   = {tag, index, 5'b0};
assign mRden_o   = C_curState == IDLE & ~C_hit & rden_i & ~cancel_i;

// When loading data into cache, Check if each 16-bit block could be a compressed instruction
wire [15:0] mCmp = {~&mData_i[241:240], ~&mData_i[225:224], ~&mData_i[209:208], ~&mData_i[193:192],
                    ~&mData_i[177:176], ~&mData_i[161:160], ~&mData_i[145:144], ~&mData_i[129:128],
                    ~&mData_i[113:112], ~&mData_i[97:96],   ~&mData_i[81:80],   ~&mData_i[65:64],
                    ~&mData_i[49:48],   ~&mData_i[33:32],   ~&mData_i[17:16],   ~&mData_i[1:0]};

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE = 1'b0;
localparam MISS = 1'b1;

reg C_curState = IDLE;

integer i;
always @(posedge clk_i) begin
        if (reset_i) begin
                for (i = 0; i < NSETS; i = i+1) begin
                        valid0[i] <= 0;
                        valid1[i] <= 0;
                end
        end else begin
                case (C_curState)
                        IDLE: begin
                                if (~rden_i | cancel_i) begin
                                        // Do nothing
                                end
                                // Check Way 0
                                else if (C_hit0) begin
                                        C_data0 <= mem0[index];
                                        C_dataWay <= 1'b0;
                                        C_offset <= offset;
                                        lru[index] <= 1'b1;
                                end
                                // Check Way 1
                                else if (C_hit1) begin
                                        C_data1 <= mem1[index];
                                        C_dataWay <= 1'b1;
                                        C_offset <= offset;
                                        lru[index] <= 1'b0;
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
                                                cmp0[index] <= mCmp;
                                                tag0[index] <= tag;
                                                valid0[index] <= 1'b1;
                                        end
                                        else if (~valid1[index]) begin
                                                mem1[index] <= mData_i;
                                                cmp1[index] <= mCmp;
                                                tag1[index] <= tag;
                                                valid1[index] <= 1'b1;
                                        end
                                        // Way 0 is Least Recently Used
                                        else if (lru[index] == 1'b0) begin
                                                mem0[index] <= mData_i;
                                                cmp0[index] <= mCmp;
                                                tag0[index] <= tag;
                                                valid0[index] <= 1'b1;
                                        end
                                        // Way 1 is Least Recently Used
                                        else if (lru[index] == 1'b1) begin
                                                mem1[index] <= mData_i;
                                                cmp1[index] <= mCmp;
                                                tag1[index] <= tag;
                                                valid1[index] <= 1'b1;
                                        end
                                        C_curState <= IDLE;
                                end
                        end

                        default: C_curState = IDLE;
                endcase
        end
end

endmodule

