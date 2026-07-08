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
        input  wire         mValidReady_i,

        // IO
        // output wire [31:0]  IO_Addr_o,
        // output wire [31:0]  IO_WData_o,
        // output wire         IO_Rden_o,
        // output wire         IO_Wren_o,
        // input  wire [31:0]  IO_RData_i,
        // input  wire         IO_ValidReady_i
        // SPI Flash
        output wire        spiClk_o,
        output wire        spiCs_o,
        inout  wire        spiMosi_io,
        input  wire        spiMiso_i,
        output wire [3:0]  leds_o,
        output wire        txd_o
);

wire isIO = addr_i[31];

wire       DCacheRden = rden_i & ~isIO;
wire [7:0] DCacheWren = isIO ? 8'b0 : wren_i;

wire [63:0] DCacheRData;
wire        DCacheValidReady;

wire [31:0] IO_addr = addr_i;
wire [63:0] IO_wData = wdata_i;
wire        IO_rstrb = isIO & rstrb;
wire [7:0]  IO_wren = isIO ? wren_i : 8'b0;
wire [63:0] IO_rData;
wire        IO_validReady;

// Turn read enable signal into strobe
reg  [31:0] prev_addr = 32'b0;
wire        rstrb     = rden_i & (addr_i != prev_addr);
always @(posedge clk_i) begin
        if (reset_i) begin
                prev_addr <= 32'b0;
        end else begin
                prev_addr <= addr_i;
        end
end

assign rdata_o = isIO ? IO_rData : DCacheRData;
assign validReady_o = isIO ? IO_validReady : DCacheValidReady;

DCache dcache(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .addr_i(addr_i),
        .flush_i(flush_i),
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
        .IO_addr_i(IO_addr),
        .IO_wData_i(IO_wData),
        .IO_rstrb_i(IO_rstrb),
        .IO_wren_i(IO_wren),
        .IO_rData_o(IO_rData),
        .IO_validReady_o(IO_validReady),
        .spiClk_o(spiClk_o),
        .spiCs_o(spiCs_o),
        .spiMosi_io(spiMosi_io),
        .spiMiso_i(spiMiso_i),
        .txd_o(txd_o),
        .leds_o(leds_o)
);
endmodule

