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
        input  wire         flush_i,
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
 * 8-Way Set Associative Read/Write Cache
 * Pseudo-LRU Replacement Policy, Write-Back, Write-Allocate
 * 32KB: 32-byte line size, 8 Ways, 128 Sets
 * Address Mapping:
 * 31       12 11 10 09 08 07 06 05 04 03 02 01 00
 * *---------* *-----------------*  *-----------*
 *     Tag           Index             Offset
 *
 *****************************************************************/
localparam NWAYS        = 8;
localparam NSETS        = 128;
localparam TAG_WIDTH    = 20;
localparam INDEX_WIDTH  = 7;
localparam OFFSET_WIDTH = 5;

`define DC_TAG 31:12
`define DC_INDEX 11:5
`define DC_OFFSET 4:0

wire [19:0] tag    = addr_i[`DC_TAG];
wire [6:0]  index  = addr_i[`DC_INDEX];
wire [4:0]  offset = addr_i[`DC_OFFSET];

// Way cache data
reg [TAG_WIDTH-1:0] C_tag   [NWAYS-1:0][0:NSETS-1];
reg                 C_valid [NWAYS-1:0][0:NSETS-1];
reg                 C_dirty [NWAYS-1:0][0:NSETS-1];

// Pseudo Least Recently Used Replacement
reg lru_0      [0:NSETS-1];
reg lru_1 [1:0][0:NSETS-1];
reg lru_2 [3:0][0:NSETS-1];
reg [2:0] C_lru;
always @(*) begin
        C_lru[2] = lru_0[index];
        if (lru_0[index]) begin
                C_lru[1] = lru_1[1][index];
                if (lru_1[1][index]) C_lru[0] = lru_2[3][index];
                else                 C_lru[0] = lru_2[2][index];
        end else begin
                C_lru[1] = lru_1[0][index];
                if (lru_1[0][index]) C_lru[0] = lru_2[1][index];
                else                 C_lru[0] = lru_2[0][index];
        end
end

/*verilator public_flat_rw_on*/
reg         C_mRden = 1'b0;
reg  [7:0]  C_mWren = 8'b0;
reg  [31:0] C_mAddr = 32'b0;

/*-------------------------------- Hit Detection --------------------------------*/
wire [NWAYS-1:0] C_hitWay;
genvar w;
generate
        for (w = 0; w < NWAYS; w = w + 1) begin : g_hit_detection
                assign C_hitWay[w] = C_valid[w][index] && (C_tag[w][index] == tag);
        end
endgenerate
wire C_hit = |C_hitWay;

reg C_allValid;
always @(*) begin: all_valid_check
        integer w;
        C_allValid = 1'b1;
        for (w = 0; w < NWAYS; w = w + 1) begin
                C_allValid = C_allValid & C_valid[w][index];
        end
end

reg  [2:0]   C_dataWay = 3'b0;
reg  [4:0]   C_offset  = 5'b0;
reg  [255:0] C_data;
always @(*) begin: data_mux
        integer w;
        C_data = 256'b0;
        for (w = 0; w < NWAYS; w = w + 1) begin
                if (C_dataWay == w[2:0])
                        C_data = m_rdata[w];
        end
end
wire [63:0]  C_dataOffset = C_offset[4] ?
                      (C_offset[3] ? C_data[255:192] : C_data[191:128]):
                      (C_offset[3] ? C_data[127:64]  : C_data[63:0]   );
/*verilator public_off*/

wire [NWAYS-1:0] C_validDirtyWay;
generate
        for (w = 0; w < NWAYS; w = w + 1) begin : g_valid_dirty
                assign C_validDirtyWay[w] = C_valid[w][flushSet] && C_dirty[w][flushSet];
        end
endgenerate
wire C_validDirty = |C_validDirtyWay;

assign validReady_o = (C_curState == IDLE & (flush_i | C_hit) & (~flush_i | flushDone)) |
        (~rden_i & ~|wren_i & ~flush_i);
assign rdata_o      = C_dataOffset;
assign mRden_o      = C_mRden;
assign mWren_o      = C_mWren;
assign mAddr_o      = C_mAddr;
assign mWData_o     = C_data;

/*-------------------------------- Cache Memory Control --------------------------------*/
wire         C_missRead = (C_curState == MISS_READ) & ~C_mRden & mValidReady_i;

wire [6:0] curIndex = flush_i ? flushSet : index;

reg          m_rden  [NWAYS-1:0];
reg   [7:0]  m_wren  [NWAYS-1:0];
wire         m_wrall [NWAYS-1:0];
wire [255:0] m_rdata [NWAYS-1:0];
wire [255:0] m_wdata [NWAYS-1:0];

generate
        for (w = 0; w < NWAYS; w = w + 1) begin : g_memory_control
                assign m_wrall[w] = C_missRead & (C_dataWay == w);
                assign m_wdata[w] = (C_curState == IDLE) ? {192'b0, wdata_i} : mRData_i;
        end
endgenerate

always @(*) begin: cache_memory_control
        integer w;
        for (w = 0; w < NWAYS; w = w + 1) begin
                m_rden[w] = 1'b0;
                m_wren[w] = 8'b0;
        end
        if (C_curState == IDLE) begin
                if (~rden_i & ~|wren_i & ~flush_i) begin
                        // Do nothing
                end else if (flush_i) begin
                        if (C_validDirty) begin
                                for (w = 0; w < NWAYS; w = w + 1) begin
                                        m_rden[w] = 1'b1;
                                end
                        end
                end else if (C_hit) begin
                        for (w = 0; w < NWAYS; w = w + 1) begin
                                if (C_hitWay[w]) begin
                                        if (rden_i)  m_rden[w] = 1'b1;
                                        if (|wren_i) m_wren[w] = wren_i;
                                end
                        end
                end else begin
                        if (C_allValid) begin
                                for (w = 0; w < NWAYS; w = w + 1) begin
                                        if (C_lru == w[2:0] && C_dirty[w][index])
                                                m_rden[w] = 1'b1;
                                end
                        end
                end
        end
end

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE       = 2'b00; // Handle Hits and determine replacement and write-back for misses
localparam MISS_WRITE = 2'b01; // Write back dirty block
localparam MISS_READ  = 2'b10; // Read data from main memory

reg [1:0] C_curState = IDLE;

reg [6:0] flushSet;
reg [7:0] flushWay;
reg       flushBusy;
reg       flushDone;

reg found = 0;
always @(posedge clk_i) begin: cache_state_machine
        integer i, w;
        if (reset_i) begin
                for (i = 0; i < NSETS; i = i+1) begin
                        for (w = 0; w < NWAYS; w = w + 1) begin
                                C_valid[w][i] <= 0;
                        end
                end
                C_curState <= IDLE;
                flushDone <= 0;
                flushBusy <= 1'b0;
        end else begin
                case (C_curState)
                IDLE: begin
                        // Reset memory read/write enable
                        C_mRden <= 1'b0;
                        C_mWren <= 8'b0;

                        // Reset Flush done and busy flags
                        if (~flush_i) begin
                                flushDone <= 1'b0;
                                flushBusy <= 1'b0;
                        end

                        if (~rden_i & ~|wren_i & ~flush_i) begin
                                // Do nothing
                                C_curState <= IDLE;
                        end
                        else if (flush_i) begin
                                if (flushDone) begin
                                        flushSet <= 0;
                                        flushBusy <= 1'b0;
                                end
                                else if (~flushBusy) begin
                                        flushSet <= 7'h7F;
                                        flushWay <= 8'b00000001;
                                        flushBusy <= 1'b1;
                                end
                                else begin
                                        for (w = 0; w < NWAYS; w = w + 1) begin
                                                if (flushWay[w]) begin
                                                        if (C_validDirtyWay[w]) begin
                                                                C_mWren <= 8'hFF;
                                                                C_mAddr <= {C_tag[w][flushSet],
                                                                        flushSet, 5'b0};
                                                                C_dataWay <= w[2:0];
                                                                C_curState <= MISS_WRITE;
                                                                C_dirty[w][flushSet] <= 1'b0;
                                                        end
                                                        if (C_valid[w][flushSet])
                                                                C_valid[w][flushSet] <= 1'b0;
                                                        flushWay <= flushWay << 1;
                                                        if (flushWay == 8'b10000000) begin
                                                                flushWay <= 8'b00000001;
                                                                flushSet <= flushSet - 1;
                                                                if (flushSet == 0)
                                                                        flushDone <= 1'b1;
                                                        end
                                                end
                                        end
                                end
                        end
                        else if (C_hit) begin
                                for (w = 0; w < NWAYS; w = w + 1) begin
                                        if (C_hitWay[w]) begin
                                                if (|wren_i)
                                                        C_dirty[w][index] <= 1'b1;
                                                C_offset <= offset;
                                                C_dataWay <= w[2:0];
                                                lru_0[index] <= w[2];
                                                if (w[2]) begin
                                                        lru_1[1][index] <= w[1];
                                                        if (w[1]) lru_2[3][index] <= w[0];
                                                        else      lru_2[2][index] <= w[0];
                                                end else begin
                                                        lru_1[0][index] <= w[1];
                                                        if (w[1]) lru_2[1][index] <= w[0];
                                                        else      lru_2[0][index] <= w[0];
                                                end
                                        end
                                end
                        end
                        // Cache Miss
                        // Check for invalid ways -- no need to evict or Write-Back
                        else if (~C_allValid) begin
                                found = 0;
                                for (w = 0; w < NWAYS; w = w + 1) begin
                                        if (~C_valid[w][index] && ~found) begin
                                                found = 1;
                                                C_tag[w][index] <= tag;
                                                C_dirty[w][index] <= 1'b0;
                                                C_valid[w][index] <= 1'b1;
                                                C_dataWay <= w[2:0];
                                                C_curState <= MISS_READ;
                                                C_mAddr <= {tag, index, 5'b0};
                                                C_mRden <= 1'b1;
                                        end
                                end
                        end
                        else begin
                                for (w = 0; w < NWAYS; w = w + 1) begin
                                        if (C_lru == w[2:0]) begin
                                                if (C_dirty[w][index]) begin
                                                        C_curState <= MISS_WRITE;
                                                        C_mWren <= 8'hFF;
                                                        C_mAddr <= {C_tag[w][index], index, 5'b0};
                                                end else begin
                                                        C_curState <= MISS_READ;
                                                        C_mAddr <= {tag, index, 5'b0};
                                                        C_mRden <= 1'b1;
                                                end
                                                C_tag[w][index] <= tag;
                                                C_valid[w][index] <= 1'b1;
                                                C_dirty[w][index] <= 1'b0;
                                                C_dataWay <= w[2:0];
                                        end
                                end
                        end
                end

                MISS_WRITE: begin
                        if (|C_mWren) begin
                                // Turn off for 1-cycle strobe
                                C_mWren <= 8'b0;
                        end else if (mValidReady_i) begin
                                if (flush_i) begin
                                        C_curState <= IDLE;
                                end else begin
                                        C_curState <= MISS_READ;
                                        C_mAddr <= {tag, index, 5'b0};
                                        C_mRden <= 1'b1;
                                end
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

initial begin: cache_initialization
        integer i, w;
        C_curState = IDLE;
        for (i = 0; i < NSETS; i = i+1) begin
                for (w = 0; w < NWAYS; w = w + 1) begin
                        C_valid[w][i] = 0;
                end
        end
end

generate
        for (w = 0; w < NWAYS; w = w + 1) begin : g_memory_instantiation
                DCacheMem #(
                        .NSETS(NSETS),
                        .INDEX_WIDTH(INDEX_WIDTH),
                        .OFFSET_WIDTH(OFFSET_WIDTH)
                )mem_inst(
                        .clk_i(clk_i),
                        .reset_i(reset_i),
                        .index_i(curIndex),
                        .offset_i(offset),
                        .rden_i(m_rden[w]),
                        .wren_i(m_wren[w]),
                        .wrall_i(m_wrall[w]),
                        .wdata_i(m_wdata[w]),
                        .rdata_o(m_rdata[w])
                );
        end
endgenerate

endmodule

