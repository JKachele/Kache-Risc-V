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
        input  wire         mValidReady_i,

        // IO
        output wire [3:0]  leds_o,
        output wire        txd_o
);

wire isIO = addr_i[31];

wire       DCacheRden = rden_i & ~isIO;
wire [7:0] DCacheWren = isIO ? 8'b0 : wren_i;
wire       IO_Wr = isIO & |wren_i;

wire [63:0] DCacheRData;
wire        DCacheValidReady;
wire [31:0] IO_RData;

assign rdata_o = isIO ? {2{IO_RData}} : DCacheRData;
assign validReady_o = isIO ? 1'b1 : DCacheValidReady;

DCache dcache(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .addr_i(addr_i),
        .rden_i(DCacheRden),
        .wdata_i(wdata_i),
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


/*-------------------------------- IO --------------------------------*/
IO io(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .IO_memRAddr_i(addr_i),
        .IO_memRData_o(IO_RData),
        .IO_memWAddr_i(addr_i),
        .IO_memWData_i(wdata_i[31:0]),
        .IO_memWr_i(IO_Wr),
        .leds_o(leds_o),
        .txd_o(txd_o)
);
endmodule

