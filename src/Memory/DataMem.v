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
        output wire [31:0] IO_addr_o,
        output wire [63:0] IO_wData_o,
        output wire        IO_rstrb_o,
        output wire [7:0]  IO_wstrb_o,
        input  wire [63:0] IO_rData_i,
        input  wire        IO_validReady_i
        // SPI Flash
        // input  wire        rtc_i,
        // output wire        spiClk_o,
        // output wire        spiCs_o,
        // inout  wire        spiMosi_io,
        // input  wire        spiMiso_i,
        // output wire [3:0]  leds_o,
        // output wire        txd_o
);

wire isIO = addr_i[31];

wire       DCacheRden = rden_i & ~isIO;
wire [7:0] DCacheWren = isIO ? 8'b0 : wren_i;

wire [63:0] DCacheRData;
wire        DCacheValidReady;

assign IO_addr_o = addr_i;
assign IO_wData_o = wdata_i;
assign IO_rstrb_o = isIO & rstrb;
assign IO_wstrb_o = isIO ? wstrb : 8'b0;

// Turn read/write enable signal into strobe
reg  [31:0] prev_addr = 32'b0;
reg         prev_rden = 1'b0;
reg  [7:0]  prev_wren = 8'b0;
wire        rstrb     = rden_i & ((addr_i != prev_addr) | (rden_i != prev_rden));
wire [7:0]  wstrb     = (|wren_i & ((addr_i != prev_addr) | (wren_i != prev_wren))) ? wren_i : 8'b0;
always @(posedge clk_i) begin
        if (reset_i) begin
                prev_addr <= 32'b0;
                prev_rden <= 1'b0;
                prev_wren <= 8'b0;
        end else begin
                prev_addr <= addr_i;
                prev_rden <= rden_i;
                prev_wren <= wren_i;
        end
end

assign rdata_o = isIO ? IO_rData_i : DCacheRData;
assign validReady_o = isIO ? IO_validReady_i : DCacheValidReady;

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
// IO io(
//         .clk_i(clk_i),
//         .reset_i(reset_i),
//         .rtc_i(rtc_i),
//         .IO_addr_i(IO_addr),
//         .IO_wData_i(IO_wData),
//         .IO_rstrb_i(IO_rstrb),
//         .IO_wstrb_i(IO_wstrb),
//         .IO_rData_o(IO_rData),
//         .IO_validReady_o(IO_validReady),
//         .TimerIRQ_o(TimerIRQ_o),
//         .spiClk_o(spiClk_o),
//         .spiCs_o(spiCs_o),
//         .spiMosi_io(spiMosi_io),
//         .spiMiso_i(spiMiso_i),
//         .txd_o(txd_o),
//         .leds_o(leds_o)
// );
endmodule

