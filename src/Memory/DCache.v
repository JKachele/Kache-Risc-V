/*************************************************
 *File----------DCache.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Jun 01, 2026 16:33:03 UTC
 ************************************************/

module DCache #(
)(
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire [31:0] addr_i,
        input  wire        rden_i,
        input  wire [63:0] wdata_i,
        input  wire [7:0]  wren_i,
        output wire [63:0] rdata_o,
        output wire        validReady_o,

        output wire [31:0] mAddr_o,
        output wire [63:0] mWData_o,
        output wire        mRden_o,
        output wire [7:0]  mWren_o,
        input  wire [63:0] mRData_i,
        input  wire        mValidReady_i
);
/*****************************************************************
 * 4-Way Set Associative Read/Write Cache
 * Pseudo-LRU Replacement Policy, Write-Back, Write-Allocate
 * 32KB: 8-byte line size, 4 Ways, 1024 Sets
 * Address Mapping:
 * 31       13 12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *--------------------------*  *-----*
 *     Tag               Index               Offset
 *
 *****************************************************************/
localparam int NSETS        = 1024;
localparam int TAG_WIDTH    = 19;
localparam int INDEX_WIDTH  = 10;
localparam int OFFSET_WIDTH = 3;

`define DC_TAG 31:13
`define DC_INDEX 12:3
`define DC_OFFSET 2:0

wire [18:0] tag    = addr_i[`DC_TAG];
wire [9:0]  index  = addr_i[`DC_INDEX];
wire [2:0]  offset = addr_i[`DC_OFFSET];

// Way 0 cache data
reg [63:0]          mem0   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag0   [0:NSETS-1];
reg                 valid0 [0:NSETS-1];
reg                 dirty0 [0:NSETS-1];

// Way 1 cache data
reg [63:0]          mem1   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag1   [0:NSETS-1];
reg                 valid1 [0:NSETS-1];
reg                 dirty1 [0:NSETS-1];

// Way 2 cache data
reg [63:0]          mem2   [0:NSETS-1];
reg [TAG_WIDTH-1:0] tag2   [0:NSETS-1];
reg                 valid2 [0:NSETS-1];
reg                 dirty2 [0:NSETS-1];

// Way 3 cache data
reg [63:0]          mem3   [0:NSETS-1];
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
reg  [63:0] C_mWData;

reg  [1:0]  C_dataWay;
reg  [63:0] C_data0;
reg  [63:0] C_data1;
reg  [63:0] C_data2;
reg  [63:0] C_data3;
wire        C_hit0 = (valid0[index] && (tag0[index] == tag));
wire        C_hit1 = (valid1[index] && (tag1[index] == tag));
wire        C_hit2 = (valid2[index] && (tag2[index] == tag));
wire        C_hit3 = (valid3[index] && (tag3[index] == tag));
wire        C_hit  = (C_hit0 | C_hit1 | C_hit2 | C_hit3) & ~uncacheable;
/*verilator public_off*/

assign validReady_o = (C_curState == IDLE & (C_hit || C_mmioReady)) | (~rden_i & ~|wren_i);
assign rdata_o      = C_dataWay[1] ?
                      (C_dataWay[0] ? C_data3 : C_data2):
                      (C_dataWay[0] ? C_data1 : C_data0);
assign mRden_o      = C_mRden;
assign mWren_o      = C_mWren;
assign mAddr_o      = C_mAddr;
assign mWData_o     = C_mWData;

// Handle memory-mapped I/O by marking address range uncacheable (8000_0000-FFFF_FFFF)
wire       uncacheable = addr_i[31]; // && addr_i[30:28] != 3'b111;
reg        C_mmioReady = 1'b0;
reg [63:0] C_mmioData;

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE       = 2'b00; // Handle Hits and determine replacement and write-back for misses
localparam MISS_WRITE = 2'b01; // Write back dirty block
localparam MISS_READ  = 2'b10; // Read data from main memory

reg [1:0] C_curState = IDLE;

always @(posedge clk_i) begin
        case (C_curState)
                IDLE: begin
                        // Reset memory read/write enable
                        C_mRden <= 1'b0;
                        C_mWren <= 8'b0;

                        if (~rden_i & ~|wren_i) begin
                                // Do nothing
                                C_curState <= IDLE;
                        end
                        // Pass uncacheable to memory
                        else if (uncacheable) begin
                                if (C_mmioReady) begin
                                        C_dataWay <= 2'b00;
                                        C_data0 <= C_mmioData;
                                        C_mmioReady <= 1'b0;
                                end
                                else if (rden_i) begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= addr_i;
                                        C_mRden <= 1'b1;
                                end else if (|wren_i) begin
                                        C_curState <= MISS_WRITE;
                                        C_mWren <= wren_i;
                                        C_mAddr <= addr_i;
                                        C_mWData <= wdata_i;
                                end
                        end
                        // Check Way 0
                        else if (C_hit0) begin
                                if (rden_i)
                                        C_data0 <= mem0[index];
                                else if (|wren_i)
                                        dirty0[index] <= 1'b1;
                                if (wren_i[0]) mem0[index][ 7:0 ] <= wdata_i[ 7:0 ];
                                if (wren_i[1]) mem0[index][15:8 ] <= wdata_i[15:8 ];
                                if (wren_i[2]) mem0[index][23:16] <= wdata_i[23:16];
                                if (wren_i[3]) mem0[index][31:24] <= wdata_i[31:24];
                                if (wren_i[4]) mem0[index][39:32] <= wdata_i[39:32];
                                if (wren_i[5]) mem0[index][47:40] <= wdata_i[47:40];
                                if (wren_i[6]) mem0[index][55:48] <= wdata_i[55:48];
                                if (wren_i[7]) mem0[index][63:56] <= wdata_i[63:56];
                                C_dataWay <= 2'b00;
                                lruTop[index] <= 1'b0;
                                lru0[index]   <= 1'b0;
                        end
                        // check way 1
                        else if (C_hit1) begin
                                if (rden_i)
                                        C_data1 <= mem1[index];
                                else if (|wren_i)
                                        dirty1[index] <= 1'b1;
                                if (wren_i[0]) mem1[index][ 7:0 ] <= wdata_i[ 7:0 ];
                                if (wren_i[1]) mem1[index][15:8 ] <= wdata_i[15:8 ];
                                if (wren_i[2]) mem1[index][23:16] <= wdata_i[23:16];
                                if (wren_i[3]) mem1[index][31:24] <= wdata_i[31:24];
                                if (wren_i[4]) mem1[index][39:32] <= wdata_i[39:32];
                                if (wren_i[5]) mem1[index][47:40] <= wdata_i[47:40];
                                if (wren_i[6]) mem1[index][55:48] <= wdata_i[55:48];
                                if (wren_i[7]) mem1[index][63:56] <= wdata_i[63:56];
                                C_dataWay <= 2'b01;
                                lruTop[index] <= 1'b0;
                                lru0[index]   <= 1'b1;
                        end
                        // check way 2
                        else if (C_hit2) begin
                                if (rden_i)
                                        C_data2 <= mem2[index];
                                else if (|wren_i)
                                        dirty2[index] <= 1'b1;
                                if (wren_i[0]) mem2[index][ 7:0 ] <= wdata_i[ 7:0 ];
                                if (wren_i[1]) mem2[index][15:8 ] <= wdata_i[15:8 ];
                                if (wren_i[2]) mem2[index][23:16] <= wdata_i[23:16];
                                if (wren_i[3]) mem2[index][31:24] <= wdata_i[31:24];
                                if (wren_i[4]) mem2[index][39:32] <= wdata_i[39:32];
                                if (wren_i[5]) mem2[index][47:40] <= wdata_i[47:40];
                                if (wren_i[6]) mem2[index][55:48] <= wdata_i[55:48];
                                if (wren_i[7]) mem2[index][63:56] <= wdata_i[63:56];
                                C_dataWay <= 2'b10;
                                lruTop[index] <= 1'b1;
                                lru1[index]   <= 1'b0;
                        end
                        // check way 3
                        else if (C_hit3) begin
                                if (rden_i)
                                        C_data3 <= mem3[index];
                                else if (|wren_i)
                                        dirty3[index] <= 1'b1;
                                if (wren_i[0]) mem3[index][ 7:0 ] <= wdata_i[ 7:0 ];
                                if (wren_i[1]) mem3[index][15:8 ] <= wdata_i[15:8 ];
                                if (wren_i[2]) mem3[index][23:16] <= wdata_i[23:16];
                                if (wren_i[3]) mem3[index][31:24] <= wdata_i[31:24];
                                if (wren_i[4]) mem3[index][39:32] <= wdata_i[39:32];
                                if (wren_i[5]) mem3[index][47:40] <= wdata_i[47:40];
                                if (wren_i[6]) mem3[index][55:48] <= wdata_i[55:48];
                                if (wren_i[7]) mem3[index][63:56] <= wdata_i[63:56];
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
                                C_mAddr <= {tag, index, 3'b0};
                                C_mRden <= 1'b1;
                        end
                        else if (~valid1[index]) begin
                                tag1[index] <= tag;
                                dirty1[index] <= 1'b0;
                                valid1[index] <= 1'b1;
                                C_dataWay <= 2'b01;
                                C_curState <= MISS_READ;
                                C_mAddr <= {tag, index, 3'b0};
                                C_mRden <= 1'b1;
                        end
                        else if (~valid2[index]) begin
                                tag2[index] <= tag;
                                dirty2[index] <= 1'b0;
                                valid2[index] <= 1'b1;
                                C_dataWay <= 2'b10;
                                C_curState <= MISS_READ;
                                C_mAddr <= {tag, index, 3'b0};
                                C_mRden <= 1'b1;
                        end
                        else if (~valid3[index]) begin
                                tag3[index] <= tag;
                                dirty3[index] <= 1'b0;
                                valid3[index] <= 1'b1;
                                C_dataWay <= 2'b11;
                                C_curState <= MISS_READ;
                                C_mAddr <= {tag, index, 3'b0};
                                C_mRden <= 1'b1;
                        end

                        // Way 0 is Least Recently Used
                        else if (lruTop[index] == 1'b0 && lru0[index] == 1'b0) begin
                                if (dirty0[index]) begin
                                        C_curState <= MISS_WRITE;
                                        C_mWren <= 8'hFF;
                                        C_mAddr <= {tag0[index], index, 3'b0};
                                        C_mWData <= mem0[index];
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 3'b0};
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
                                        C_mAddr <= {tag1[index], index, 3'b0};
                                        C_mWData <= mem1[index];
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 3'b0};
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
                                        C_mAddr <= {tag2[index], index, 3'b0};
                                        C_mWData <= mem2[index];
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 3'b0};
                                        C_mRden <= 1'b1;
                                end
                                tag2[index] <= tag;
                                valid2[index] <= 1'b1;
                                dirty2[index] <= 1'b0;
                                C_dataWay <= 2'b10;
                        end
                        // Way 3 is Least Recently Used
                        else if (lruTop[index] == 1'b1 && lru0[index] == 1'b1) begin
                                if (dirty3[index]) begin
                                        C_curState <= MISS_WRITE;
                                        C_mWren <= 8'hFF;
                                        C_mAddr <= {tag3[index], index, 3'b0};
                                        C_mWData <= mem3[index];
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 3'b0};
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
                                if (uncacheable) begin
                                        C_curState <= IDLE;
                                        C_mmioReady <= 1'b1;
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 3'b0};
                                        C_mRden <= 1'b1;
                                end
                        end
                end

                MISS_READ: begin
                        if (C_mRden) begin
                                // Turn off for 1-cycle strobe
                                C_mRden <= 1'b0;
                        end else if (mValidReady_i) begin
                                if (uncacheable) begin
                                        C_mmioReady <= 1'b1;
                                        C_mmioData <= mRData_i;
                                end
                                else if (C_dataWay == 2'b00)
                                        mem0[index] <= mRData_i;
                                else if (C_dataWay == 2'b01)
                                        mem1[index] <= mRData_i;
                                else if (C_dataWay == 2'b10)
                                        mem2[index] <= mRData_i;
                                else if (C_dataWay == 2'b11)
                                        mem3[index] <= mRData_i;
                                C_curState <= IDLE;
                        end
                end

                default: C_curState = IDLE;
        endcase
end

endmodule


