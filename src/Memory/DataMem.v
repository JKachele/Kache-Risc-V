/*************************************************
 *File----------DataMem.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Jun 30, 2026 14:05:29 EDT
 ************************************************/

module DataMem (
        input  wire         clk_i,
        input  wire         reset_i,

        // CPU Interface
        input  wire [31:0]  cpu_addr_i,
        input  wire         cpu_flush_i,
        input  wire         cpu_mmu_valid_i,
        input  wire [1:0]   cpu_mmu_fault_i,
        input  wire         cpu_rden_i,
        input  wire [63:0]  cpu_wdata_i,
        input  wire [7:0]   cpu_wren_i,
        output wire [63:0]  cpu_rdata_o,
        output wire         cpu_validReady_o,

        // MMU Interface
        input  wire [31:0]  mmu_addr_i,
        input  wire         mmu_rden_i,
        input  wire [63:0]  mmu_wdata_i,
        input  wire [7:0]   mmu_wren_i,
        output wire [63:0]  mmu_rdata_o,
        output wire         mmu_validReady_o,

        output wire [31:0]  mAddr_o,
        output wire [255:0] mWData_o,
        output wire         mRden_o,
        output wire [7:0]   mWren_o,
        input  wire [255:0] mRData_i,
        input  wire         mValidReady_i,

        // IO
        output wire [31:0] IO_addr_o,
        output wire [63:0] IO_wData_o,
        output wire        IO_rstrb_o,
        output wire [7:0]  IO_wstrb_o,
        input  wire [63:0] IO_rData_i,
        input  wire        IO_validReady_i
);
wire       cpu_rden = cpu_mmu_valid_i & cpu_rden_i;
wire [7:0] cpu_wren = cpu_mmu_valid_i ? cpu_wren_i : 8'b0;
wire       cpu_validReady;
assign cpu_validReady_o = (cpu_mmu_valid_i & cpu_validReady) | |cpu_mmu_fault_i;
/*-------------------------------- Arbiter --------------------------------*/
wire [31:0]  DM_addr;
wire         DM_flush;
wire         DM_rden;
wire [63:0]  DM_wdata;
wire [7:0]   DM_wren;
wire [63:0]  DM_rdata;
wire         DM_validReady;

DMemArb arbiter(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .cpu_addr_i(cpu_addr_i),
        .cpu_flush_i(cpu_flush_i),
        .cpu_rden_i(cpu_rden),
        .cpu_wdata_i(cpu_wdata_i),
        .cpu_wren_i(cpu_wren),
        .cpu_rdata_o(cpu_rdata_o),
        .cpu_validReady_o(cpu_validReady),

        .mmu_addr_i(mmu_addr_i),
        .mmu_rden_i(mmu_rden_i),
        .mmu_wdata_i(mmu_wdata_i),
        .mmu_wren_i(mmu_wren_i),
        .mmu_rdata_o(mmu_rdata_o),
        .mmu_validReady_o(mmu_validReady_o),

        .dmem_addr_o(DM_addr),
        .dmem_flush_o(DM_flush),
        .dmem_rden_o(DM_rden),
        .dmem_wdata_o(DM_wdata),
        .dmem_wren_o(DM_wren),
        .dmem_rdata_i(DM_rdata),
        .dmem_validReady_i(DM_validReady)
);

wire isIO = DM_addr[31];

wire       DCacheRden = DM_rden & ~isIO;
wire [7:0] DCacheWren = isIO ? 8'b0 : DM_wren;

wire [63:0] DCacheRData;
wire        DCacheValidReady;

assign IO_addr_o = DM_addr;
assign IO_wData_o = DM_wdata;
assign IO_rstrb_o = isIO & rstrb;
assign IO_wstrb_o = isIO ? wstrb : 8'b0;

// Turn read/write enable signal into strobe
reg  [31:0] prev_addr = 32'b0;
reg         prev_rden = 1'b0;
reg  [7:0]  prev_wren = 8'b0;
wire        rstrb     = DM_rden & ((DM_addr != prev_addr) | (DM_rden != prev_rden));
wire [7:0]  wstrb     = (|DM_wren & ((DM_addr != prev_addr) | (DM_wren != prev_wren))) ?
                        DM_wren : 8'b0;
always @(posedge clk_i) begin
        if (reset_i) begin
                prev_addr <= 32'b0;
                prev_rden <= 1'b0;
                prev_wren <= 8'b0;
        end else begin
                prev_addr <= DM_addr;
                prev_rden <= DM_rden;
                prev_wren <= DM_wren;
        end
end

assign DM_rdata = isIO ? IO_rData_i : DCacheRData;
assign DM_validReady = isIO ? IO_validReady_i : DCacheValidReady;

DCache dcache(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .addr_i(DM_addr),
        .flush_i(DM_flush),
        .rden_i(DCacheRden),
        .wdata_i(DM_wdata),
        .wren_i(DCacheWren),
        .rdata_o(DCacheRData),
        .validReady_o(DCacheValidReady),
        .mAddr_o(mAddr_o),
        .mWData_o(mWData_o),
        .mRden_o(mRden_o),
        .mWren_o(mWren_o),
        .mRData_i(mRData_i),
        .mValidReady_i(mValidReady_i)
);

endmodule

