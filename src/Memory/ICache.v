/*************************************************
 *File----------ICache.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday May 13, 2026 20:44:47 UTC
 ************************************************/

module ICache (
        input  wire         clk_i,
        input  wire         reset_i,

        input  wire [11:0]  index_offset_i,
        input  wire [19:0]  tag_i,
        input  wire         rden_i,
        input  wire         mmu_valid_i,
        input  wire         mmu_fault_i,
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
 * 4-Way Set Associative Read-Only Cache
 * Pseudo LRU Replacement Policy
 * 16KB: 32-byte line size, 4 Ways, 128 Sets
 * Address Mapping:
 * 31       12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *-----------------*  *-----------*
 *     Tag           Index             Offset
 *
 *****************************************************************/
localparam NSETS        = 128;
localparam TAG_WIDTH    = 20;
localparam INDEX_WIDTH  = 7;
localparam OFFSET_WIDTH = 5;

`define IC_TAG 31:12
`define IC_INDEX 11:5
`define IC_OFFSET 4:0

wire [6:0]  index  = index_offset_i[`IC_INDEX];
wire [4:0]  offset = index_offset_i[`IC_OFFSET];

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

// Way 2 cache data
reg [255:0]         mem2   [0:NSETS-1];
reg [15:0]          cmp2   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag2   [0:NSETS-1];
reg                 valid2 [0:NSETS-1];

// Way 3 cache data
reg [255:0]         mem3   [0:NSETS-1];
reg [15:0]          cmp3   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag3   [0:NSETS-1];
reg                 valid3 [0:NSETS-1];

// Pseudo Least Recently Used Replacement
reg lruTop [0:NSETS-1];
reg lru0   [0:NSETS-1]; // Ways 0 and 1
reg lru1   [0:NSETS-1]; // Ways 2 and 3

reg  [4:0]   C_offset  = 5'b0;
reg  [1:0]   C_dataWay = 2'b0;
reg  [255:0] C_data0;
reg  [255:0] C_data1;
reg  [255:0] C_data2;
reg  [255:0] C_data3;
wire [255:0] C_data = C_dataWay[1] ?
                      (C_dataWay[0] ? C_data3 : C_data2):
                      (C_dataWay[0] ? C_data1 : C_data0);
wire         C_hit0 = (valid0[index] && (tag0[index] == tag_i));
wire         C_hit1 = (valid1[index] && (tag1[index] == tag_i));
wire         C_hit2 = (valid2[index] && (tag2[index] == tag_i));
wire         C_hit3 = (valid3[index] && (tag3[index] == tag_i));
wire         C_hit  = (C_hit0 | C_hit1 | C_hit2 | C_hit3);

wire         C_cmp0 = cmp0[index][offset[4:1]];
wire         C_cmp1 = cmp1[index][offset[4:1]];
wire         C_cmp2 = cmp2[index][offset[4:1]];
wire         C_cmp3 = cmp3[index][offset[4:1]];

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

assign valid_o   = cancel_i | mmu_fault_i | (C_curState == IDLE & C_hit & mmu_valid_i) | ~rden_i;
assign data_o    = C_offsetData;
assign cmp_o     = C_hit0 ? C_cmp0 : (C_hit1 ? C_cmp1 : (C_hit2 ? C_cmp2 : C_cmp3));
assign mAddr_o   = {tag_i, index, 5'b0};
assign mRden_o   = C_curState == IDLE & ~C_hit & rden_i & mmu_valid_i & ~cancel_i;

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
                        valid2[i] <= 0;
                        valid3[i] <= 0;
                end
                C_curState <= IDLE;
        end else begin
                case (C_curState)
                        IDLE: begin
                                if (~rden_i | ~mmu_valid_i | cancel_i) begin
                                        // Do nothing
                                end
                                // Check Way 0
                                else if (C_hit0) begin
                                        C_data0 <= mem0[index];
                                        C_dataWay <= 2'b00;
                                        C_offset <= offset;
                                        lruTop[index] <= 1'b0;
                                        lru0[index]   <= 1'b0;
                                end
                                // Check Way 1
                                else if (C_hit1) begin
                                        C_data1 <= mem1[index];
                                        C_dataWay <= 2'b01;
                                        C_offset <= offset;
                                        lruTop[index] <= 1'b0;
                                        lru0[index]   <= 1'b1;
                                end
                                // Check Way 2
                                else if (C_hit2) begin
                                        C_data2 <= mem2[index];
                                        C_dataWay <= 2'b10;
                                        C_offset <= offset;
                                        lruTop[index] <= 1'b1;
                                        lru1[index]   <= 1'b0;
                                end
                                // Check Way 3
                                else if (C_hit3) begin
                                        C_data3 <= mem3[index];
                                        C_dataWay <= 2'b11;
                                        C_offset <= offset;
                                        lruTop[index] <= 1'b1;
                                        lru1[index]   <= 1'b1;
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
                                                tag0[index] <= tag_i;
                                                valid0[index] <= 1'b1;
                                        end
                                        else if (~valid1[index]) begin
                                                mem1[index] <= mData_i;
                                                cmp1[index] <= mCmp;
                                                tag1[index] <= tag_i;
                                                valid1[index] <= 1'b1;
                                        end
                                        else if (~valid2[index]) begin
                                                mem2[index] <= mData_i;
                                                cmp2[index] <= mCmp;
                                                tag2[index] <= tag_i;
                                                valid2[index] <= 1'b1;
                                        end
                                        else if (~valid3[index]) begin
                                                mem3[index] <= mData_i;
                                                cmp3[index] <= mCmp;
                                                tag3[index] <= tag_i;
                                                valid3[index] <= 1'b1;
                                        end
                                        // All ways are valid, use LRU replacement policy
                                        else if (lruTop[index] == 1'b0) begin
                                                // Way 0 is Least Recently Used
                                                if (lru0[index] == 1'b0) begin
                                                        mem0[index] <= mData_i;
                                                        cmp0[index] <= mCmp;
                                                        tag0[index] <= tag_i;
                                                        valid0[index] <= 1'b1;
                                                end
                                                // Way 1 is Least Recently Used
                                                else begin
                                                        mem1[index] <= mData_i;
                                                        cmp1[index] <= mCmp;
                                                        tag1[index] <= tag_i;
                                                        valid1[index] <= 1'b1;
                                                end
                                        end
                                        else if (lruTop[index] == 1'b1) begin
                                                // Way 2 is Least Recently Used
                                                if (lru1[index] == 1'b0) begin
                                                        mem2[index] <= mData_i;
                                                        cmp2[index] <= mCmp;
                                                        tag2[index] <= tag_i;
                                                        valid2[index] <= 1'b1;
                                                end
                                                // Way 3 is Least Recently Used
                                                else begin
                                                        mem3[index] <= mData_i;
                                                        cmp3[index] <= mCmp;
                                                        tag3[index] <= tag_i;
                                                        valid3[index] <= 1'b1;
                                                end
                                        end
                                        C_curState <= IDLE;
                                end
                        end

                        default: C_curState = IDLE;
                endcase
        end
end

initial begin
        C_curState = IDLE;
        for (i = 0; i < NSETS; i = i+1) begin
                valid0[i] = 0;
                valid1[i] = 0;
                valid2[i] = 0;
                valid3[i] = 0;
        end
end

endmodule

