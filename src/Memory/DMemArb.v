/*************************************************
 *File----------DMemArb.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 11:14:49 EDT
 ************************************************/

module DMemArb (
        input  wire         clk_i,
        input  wire         reset_i,

        // CPU Interface
        input  wire [31:0]  cpu_addr_i,
        input  wire         cpu_flush_i,
        input  wire         cpu_rden_i,
        input  wire [63:0]  cpu_wdata_i,
        input  wire [7:0]   cpu_wren_i,
        output reg  [63:0]  cpu_rdata_o,
        output reg          cpu_validReady_o,

        // MMU Interface
        input  wire [31:0]  mmu_addr_i,
        input  wire         mmu_rden_i,
        input  wire [63:0]  mmu_wdata_i,
        input  wire [7:0]   mmu_wren_i,
        output reg  [63:0]  mmu_rdata_o,
        output reg          mmu_validReady_o,

        output reg  [31:0]  dmem_addr_o,
        output reg          dmem_flush_o,
        output reg          dmem_rden_o,
        output reg  [63:0]  dmem_wdata_o,
        output reg  [7:0]   dmem_wren_o,
        input  wire [63:0]  dmem_rdata_i,
        input  wire         dmem_validReady_i
);
localparam CPU = 1'b0;
localparam MMU = 1'b1;

reg arb_state = CPU;
reg arb_sel   = CPU;
reg mmu_req   = 1'b0;

// Strobe Signals
reg        mmu_prev_rden = 1'b0;
reg [7:0]  mmu_prev_wren = 8'b0;
reg [31:0] mmu_prev_addr = 32'b0;

wire mmu_rstrb =  mmu_rden_i & ((mmu_prev_addr != mmu_addr_i) | (mmu_prev_rden != mmu_rden_i));
wire mmu_wstrb = |mmu_wren_i & ((mmu_prev_addr != mmu_addr_i) | (mmu_prev_wren != mmu_wren_i));

always @(*) begin
        if (arb_sel == CPU) begin
                dmem_addr_o      = cpu_addr_i;
                dmem_flush_o     = cpu_flush_i;
                dmem_rden_o      = cpu_rden_i;
                dmem_wdata_o     = cpu_wdata_i;
                dmem_wren_o      = cpu_wren_i;
                cpu_rdata_o      = dmem_rdata_i;
                cpu_validReady_o = dmem_validReady_i;
                mmu_rdata_o      = 64'b0;
                mmu_validReady_o = 1'b0;
        end else begin
                dmem_addr_o      = mmu_addr_i;
                dmem_flush_o     = 1'b0;
                dmem_rden_o      = mmu_rden_i;
                dmem_wdata_o     = mmu_wdata_i;
                dmem_wren_o      = mmu_wren_i;
                mmu_rdata_o      = dmem_rdata_i;
                mmu_validReady_o = dmem_validReady_i;
                cpu_rdata_o      = 64'b0;
                cpu_validReady_o = ~cpu_rden_i & ~(|cpu_wren_i);
        end
end

always @(posedge clk_i) begin
        if (reset_i) begin
                arb_state <= CPU;
                arb_sel   <= CPU;
                mmu_req   <= 1'b0;
                mmu_prev_rden <= 1'b0;
                mmu_prev_wren <= 8'b0;
                mmu_prev_addr <= 32'b0;
        end else if (arb_state == CPU) begin
                if (dmem_validReady_i & mmu_req) begin
                        arb_state <= MMU;
                        arb_sel   <= MMU;
                end else begin
                        arb_sel   <= CPU;
                end
        end else if (arb_state == MMU) begin
                if (dmem_validReady_i) begin
                        mmu_req   <= 1'b0;
                        arb_state <= CPU;
                end
        end else begin
                arb_state <= CPU;
        end

        if (~reset_i) begin
                if (~mmu_req & (mmu_rstrb | mmu_wstrb)) begin
                        mmu_req <= 1'b1;
                end
                mmu_prev_rden <= mmu_rden_i;
                mmu_prev_wren <= mmu_wren_i;
                mmu_prev_addr <= mmu_addr_i;
        end
end

endmodule

