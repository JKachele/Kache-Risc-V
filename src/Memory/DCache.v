/*************************************************
 *File----------DCache.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Jun 01, 2026 16:33:03 UTC
 ************************************************/

module DCache (
        input  wire         clk_i,
        input  wire         reset_i,

        input  wire [31:0]  addr_i,
        input  wire         rden_i,
        input  wire [63:0]  wdata_i,
        input  wire [7:0]   wren_i,
        output wire [63:0]  rdata_o,
        output wire         validReady_o,

        output wire [31:0]  mAddr_o,
        output wire [255:0] mWData_o,
        output wire         mRden_o,
        output wire [7:0]   mWren_o,
        input  wire [255:0] mRData_i,
        input  wire         mValidReady_i
);

/*****************************************************************
 * 4-Way Set Associative Read/Write Cache
 * Pseudo-LRU Replacement Policy, Write-Back, Write-Allocate
 * 32KB: 32-byte line size, 4 Ways, 256 Sets
 * Address Mapping:
 * 31       13 12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *--------------------*  *-----------*
 *     Tag             Index              Offset
 *
 *****************************************************************/
localparam NSETS        = 256;
localparam TAG_WIDTH    = 19;
localparam INDEX_WIDTH  = 8;
localparam OFFSET_WIDTH = 5;

`define DC_TAG 31:13
`define DC_INDEX 12:5
`define DC_OFFSET 4:0

wire [18:0] tag    = addr_i[`DC_TAG];
wire [7:0]  index  = addr_i[`DC_INDEX];
wire [4:0]  offset = addr_i[`DC_OFFSET];

// Way 0 cache data
reg [TAG_WIDTH-1:0] tag0   [0:NSETS-1];
reg                 valid0 [0:NSETS-1];
reg                 dirty0 [0:NSETS-1];

// Way 1 cache data
reg [TAG_WIDTH-1:0] tag1   [0:NSETS-1];
reg                 valid1 [0:NSETS-1];
reg                 dirty1 [0:NSETS-1];

// Way 2 cache data
reg [TAG_WIDTH-1:0] tag2   [0:NSETS-1];
reg                 valid2 [0:NSETS-1];
reg                 dirty2 [0:NSETS-1];

// Way 3 cache data
reg [TAG_WIDTH-1:0] tag3   [0:NSETS-1];
reg                 valid3 [0:NSETS-1];
reg                 dirty3 [0:NSETS-1];

// Pseudo Least Recently Used Replacement
reg lruTop [0:NSETS-1];
reg lru0   [0:NSETS-1]; // Ways 0 and 1
reg lru1   [0:NSETS-1]; // Ways 2 and 3

/*verilator public_flat_rw_on*/
reg         C_mRden  = 1'b0;
reg  [7:0]  C_mWren  = 8'b0;
reg  [31:0] C_mAddr;

wire         C_hit0 = (valid0[index] && (tag0[index] == tag));
wire         C_hit1 = (valid1[index] && (tag1[index] == tag));
wire         C_hit2 = (valid2[index] && (tag2[index] == tag));
wire         C_hit3 = (valid3[index] && (tag3[index] == tag));
wire         C_hit  = (C_hit0 | C_hit1 | C_hit2 | C_hit3);
reg  [1:0]   C_dataWay;
reg  [4:0]   C_offset;
wire [255:0] C_data = C_dataWay[1] ?
                      (C_dataWay[0] ? m3_rdata : m2_rdata):
                      (C_dataWay[0] ? m1_rdata : m0_rdata);
wire [63:0]  C_dataOffset = C_offset[4] ?
                      (C_offset[3] ? C_data[255:192] : C_data[191:128]):
                      (C_offset[3] ? C_data[127:64]  : C_data[63:0]   );
/*verilator public_off*/

assign validReady_o = (C_curState == IDLE & (C_hit)) | (~rden_i & ~|wren_i);
assign rdata_o      = C_dataOffset;
assign mRden_o      = C_mRden;
assign mWren_o      = C_mWren;
assign mAddr_o      = C_mAddr;
assign mWData_o     = C_data;

/*-------------------------------- Cache Memory Control --------------------------------*/
wire         C_missRead = (C_curState == MISS_READ) & ~C_mRden & mValidReady_i;

reg          m0_rden;
reg   [7:0]  m0_wren;
wire         m0_wrall = C_missRead & (C_dataWay == 2'b00);
wire [255:0] m0_rdata;
wire [255:0] m0_wdata = (C_curState == IDLE) ? {192'b0, wdata_i} : mRData_i;
reg          m1_rden;
reg   [7:0]  m1_wren;
wire         m1_wrall = C_missRead & (C_dataWay == 2'b01);
wire [255:0] m1_rdata;
wire [255:0] m1_wdata = (C_curState == IDLE) ? {192'b0, wdata_i} : mRData_i;
reg          m2_rden;
reg   [7:0]  m2_wren;
wire         m2_wrall = C_missRead & (C_dataWay == 2'b10);
wire [255:0] m2_rdata;
wire [255:0] m2_wdata = (C_curState == IDLE) ? {192'b0, wdata_i} : mRData_i;
reg          m3_rden;
reg   [7:0]  m3_wren;
wire         m3_wrall = C_missRead & (C_dataWay == 2'b11);
wire [255:0] m3_rdata;
wire [255:0] m3_wdata = (C_curState == IDLE) ? {192'b0, wdata_i} : mRData_i;

always @(*) begin
        m0_rden  = 1'b0;
        m0_wren  = 8'b0;
        m1_rden  = 1'b0;
        m1_wren  = 8'b0;
        m2_rden  = 1'b0;
        m2_wren  = 8'b0;
        m3_rden  = 1'b0;
        m3_wren  = 8'b0;
        if (C_curState == IDLE) begin
                if (~rden_i & ~|wren_i) begin
                        // Do nothing
                end else if (C_hit0) begin
                        if (rden_i)  m0_rden = 1'b1;
                        if (|wren_i) m0_wren = wren_i;
                end else if (C_hit1) begin
                        if (rden_i)  m1_rden = 1'b1;
                        if (|wren_i) m1_wren = wren_i;
                end else if (C_hit2) begin
                        if (rden_i)  m2_rden = 1'b1;
                        if (|wren_i) m2_wren = wren_i;
                end else if (C_hit3) begin
                        if (rden_i)  m3_rden = 1'b1;
                        if (|wren_i) m3_wren = wren_i;
                end
                else if (valid0[index] & valid1[index] & valid2[index] & valid3[index]) begin
                        if (lruTop[index] == 1'b0 && lru0[index] == 1'b0 && dirty0[index])
                                m0_rden = 1'b1;
                        else if (lruTop[index] == 1'b0 && lru0[index] == 1'b1 && dirty1[index])
                                m1_rden = 1'b1;
                        else if (lruTop[index] == 1'b1 && lru1[index] == 1'b0 && dirty2[index])
                                m2_rden = 1'b1;
                        else if (lruTop[index] == 1'b1 && lru1[index] == 1'b1 && dirty3[index])
                                m3_rden = 1'b1;
                end
        end
end

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE       = 2'b00; // Handle Hits and determine replacement and write-back for misses
localparam MISS_WRITE = 2'b01; // Write back dirty block
localparam MISS_READ  = 2'b10; // Read data from main memory

reg [1:0] C_curState = IDLE;

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
                                // Reset memory read/write enable
                                C_mRden <= 1'b0;
                                C_mWren <= 8'b0;

                                if (~rden_i & ~|wren_i) begin
                                        // Do nothing
                                        C_curState <= IDLE;
                                end
                                // Check Way 0
                                else if (C_hit0) begin
                                        if (|wren_i)
                                                dirty0[index] <= 1'b1;
                                        C_offset <= offset;
                                        C_dataWay <= 2'b00;
                                        lruTop[index] <= 1'b0;
                                        lru0[index]   <= 1'b0;
                                end
                                // check way 1
                                else if (C_hit1) begin
                                        if (|wren_i)
                                                dirty1[index] <= 1'b1;
                                        C_offset <= offset;
                                        C_dataWay <= 2'b01;
                                        lruTop[index] <= 1'b0;
                                        lru0[index]   <= 1'b1;
                                end
                                // check way 2
                                else if (C_hit2) begin
                                        if (|wren_i)
                                                dirty2[index] <= 1'b1;
                                        C_offset <= offset;
                                        C_dataWay <= 2'b10;
                                        lruTop[index] <= 1'b1;
                                        lru1[index]   <= 1'b0;
                                end
                                // check way 3
                                else if (C_hit3) begin
                                        if (|wren_i)
                                                dirty3[index] <= 1'b1;
                                        C_offset <= offset;
                                        C_dataWay <= 2'b11;
                                        lruTop[index] <= 1'b1;
                                        lru1[index]   <= 1'b1;
                                end
                                // Cache Miss
                                // Check for invalid ways -- no need to evict or Write-Back
                                else if (~valid0[index]) begin
                                        tag0[index] <= tag;
                                        dirty0[index] <= 1'b0;
                                        valid0[index] <= 1'b1;
                                        C_dataWay <= 2'b00;
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end
                                else if (~valid1[index]) begin
                                        tag1[index] <= tag;
                                        dirty1[index] <= 1'b0;
                                        valid1[index] <= 1'b1;
                                        C_dataWay <= 2'b01;
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end
                                else if (~valid2[index]) begin
                                        tag2[index] <= tag;
                                        dirty2[index] <= 1'b0;
                                        valid2[index] <= 1'b1;
                                        C_dataWay <= 2'b10;
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end
                                else if (~valid3[index]) begin
                                        tag3[index] <= tag;
                                        dirty3[index] <= 1'b0;
                                        valid3[index] <= 1'b1;
                                        C_dataWay <= 2'b11;
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end

                                // Way 0 is Least Recently Used
                                else if (lruTop[index] == 1'b0 && lru0[index] == 1'b0) begin
                                        if (dirty0[index]) begin
                                                C_curState <= MISS_WRITE;
                                                C_mWren <= 8'hFF;
                                                C_mAddr <= {tag0[index], index, 5'b0};
                                        end else begin
                                                C_curState <= MISS_READ;
                                                C_mAddr <= {tag, index, 5'b0};
                                                C_mRden <= 1'b1;
                                        end
                                        tag0[index] <= tag;
                                        valid0[index] <= 1'b1;
                                        dirty0[index] <= 1'b0;
                                        C_dataWay <= 2'b00;
                                end
                                // Way 1 is Least Recently Used
                                else if (lruTop[index] == 1'b0 && lru0[index] == 1'b1) begin
                                        if (dirty1[index]) begin
                                                C_curState <= MISS_WRITE;
                                                C_mWren <= 8'hFF;
                                                C_mAddr <= {tag1[index], index, 5'b0};
                                        end else begin
                                                C_curState <= MISS_READ;
                                                C_mAddr <= {tag, index, 5'b0};
                                                C_mRden <= 1'b1;
                                        end
                                        tag1[index] <= tag;
                                        valid1[index] <= 1'b1;
                                        dirty1[index] <= 1'b0;
                                        C_dataWay <= 2'b01;
                                end
                                // Way 2 is Least Recently Used
                                else if (lruTop[index] == 1'b1 && lru1[index] == 1'b0) begin
                                        if (dirty2[index]) begin
                                                C_curState <= MISS_WRITE;
                                                C_mWren <= 8'hFF;
                                                C_mAddr <= {tag2[index], index, 5'b0};
                                        end else begin
                                                C_curState <= MISS_READ;
                                                C_mAddr <= {tag, index, 5'b0};
                                                C_mRden <= 1'b1;
                                        end
                                        tag2[index] <= tag;
                                        valid2[index] <= 1'b1;
                                        dirty2[index] <= 1'b0;
                                        C_dataWay <= 2'b10;
                                end
                                // Way 3 is Least Recently Used
                                else if (lruTop[index] == 1'b1 && lru1[index] == 1'b1) begin
                                        if (dirty3[index]) begin
                                                C_curState <= MISS_WRITE;
                                                C_mWren <= 8'hFF;
                                                C_mAddr <= {tag3[index], index, 5'b0};
                                        end else begin
                                                C_curState <= MISS_READ;
                                                C_mAddr <= {tag, index, 5'b0};
                                                C_mRden <= 1'b1;
                                        end
                                        tag3[index] <= tag;
                                        valid3[index] <= 1'b1;
                                        dirty3[index] <= 1'b0;
                                        C_dataWay <= 2'b11;
                                end
                        end

                        MISS_WRITE: begin
                                if (|C_mWren) begin
                                        // Turn off for 1-cycle strobe
                                        C_mWren <= 8'b0;
                                end else if (mValidReady_i) begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end
                        end

                        MISS_READ: begin
                                if (C_mRden) begin
                                        // Turn off for 1-cycle strobe
                                        C_mRden <= 1'b0;
                                end else if (mValidReady_i) begin
                                        C_curState <= IDLE;
                                end
                        end

                        default: C_curState = IDLE;
                endcase
        end
end

DCacheMem #(
        .NSETS(NSETS),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH)
)mem0(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .index_i(index),
        .offset_i(offset),
        .rden_i(m0_rden),
        .wren_i(m0_wren),
        .wrall_i(m0_wrall),
        .wdata_i(m0_wdata),
        .rdata_o(m0_rdata)
);

DCacheMem #(
        .NSETS(NSETS),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH)
)mem1(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .index_i(index),
        .offset_i(offset),
        .rden_i(m1_rden),
        .wren_i(m1_wren),
        .wrall_i(m1_wrall),
        .wdata_i(m1_wdata),
        .rdata_o(m1_rdata)
);

DCacheMem #(
        .NSETS(NSETS),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH)
)mem2(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .index_i(index),
        .offset_i(offset),
        .rden_i(m2_rden),
        .wren_i(m2_wren),
        .wrall_i(m2_wrall),
        .wdata_i(m2_wdata),
        .rdata_o(m2_rdata)
);

DCacheMem #(
        .NSETS(NSETS),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH)
)mem3(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .index_i(index),
        .offset_i(offset),
        .rden_i(m3_rden),
        .wren_i(m3_wren),
        .wrall_i(m3_wrall),
        .wdata_i(m3_wdata),
        .rdata_o(m3_rdata)
);

endmodule



