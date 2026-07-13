/*************************************************
 *File----------IO.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 01, 2025 16:48:14 UTC
 ************************************************/

module IO (
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire        rtc_i,
        input  wire [31:0] IO_addr_i,
        input  wire [63:0] IO_wData_i,
        input  wire        IO_rstrb_i,
        input  wire [7:0]  IO_wstrb_i,
        output wire [63:0] IO_rData_o,
        output wire        IO_validReady_o,
        output wire        TimerIRQ_o,

        // SPI Flash
        output wire        spiClk_o,
        output wire        spiCs_o,
        inout  wire        spiMosi_io,
        input  wire        spiMiso_i,

        // UART
        output wire        txd_o,

        // Basic IO
        output wire [3:0]  leds_o
);

// addr[31] is always 1 for IO
wire isMMReg = (IO_addr_i[30:28] == 3'b000);
wire isFlash = (IO_addr_i[30:28] == 3'b001);
wire isBasic = (IO_addr_i[30:28] == 3'b111);
wire isUART  = isBasic & (IO_addr_i[27:3] == 25'b0);
reg  isMMReg_r;
reg  isFlash_r;
reg  isBasic_r;
reg  isUART_r;

always @(posedge clk_i) begin
        if (reset_i) begin
                isMMReg_r <= 1'b0;
                isFlash_r <= 1'b0;
                isBasic_r <= 1'b0;
                isUART_r <= 1'b0;
        end else if (IO_rstrb_i) begin
                isMMReg_r <= isMMReg;
                isFlash_r <= isFlash;
                isBasic_r <= isBasic;
                isUART_r <= isUART;
        end
end

assign IO_rData_o = isFlash_r ? SPI_Data : (isUART_r ? {2{uartRData}} : 64'b0);
assign IO_validReady_o = isFlash ? SPI_valid : 1'b1;

/*-------------------------------- Memory Mapped Registers --------------------------------*/
/* verilator lint_off MULTIDRIVEN */
(* ram_style = "block" *) reg [63:0] mtime [0:1]; // mtime[0] = mtime, mtime[1] = mtimecmp

wire isMTime = isMMReg & (IO_addr_i[27:3] == 25'h0) & (IO_rstrb_i | |IO_wstrb_i);
wire isMTimecmp = isMMReg & (IO_addr_i[27:3] == 25'h1) & (IO_rstrb_i | |IO_wstrb_i);
reg  [63:0] mtimeRData;
reg  [63:0] mtimecmpRData;

// Registers used to declare an interupt
reg  [63:0] mtimeData;
reg  [63:0] mtimecmpData;
assign TimerIRQ_o = (mtimeData >= mtimecmpData) ? 1'b1 : 1'b0;

integer i;
always @(posedge clk_i) begin
        if (isMTime) begin
                for (i = 0; i < 8; i = i+1) begin
                        if (IO_wstrb_i[i]) begin
                                mtime[0][i*8 +: 8] <= IO_wData_i[i*8 +: 8];
                        end
                end
                if (IO_rstrb_i) begin
                        mtimeRData <= mtime[0];
                end
                mtimeData <= mtime[0];
        end else if (isMTimecmp) begin
                for (i = 0; i < 8; i = i+1) begin
                        if (IO_wstrb_i[i]) begin
                                mtime[1][i*8 +: 8] <= IO_wData_i[i*8 +: 8];
                        end
                end
                if (IO_rstrb_i) begin
                        mtimecmpRData <= mtime[1];
                end
                mtimecmpData <= mtime[1];
        end
end

always @(posedge rtc_i) begin
        mtime[0] <= mtime[0] + 1;
end

// generate
//         genvar i;
//         for (i = 0; i < 8; i = i+1) begin: g_byte_write
//                 always @(posedge clk_i) begin
//                         if (isMTime) begin
//                                 if (IO_wstrb_i[i]) begin
//                                         mtime[0][(i+1)*7:i*8] <= IO_wData_i[(i+1)*7:i*8];
//                                         mtimeData[(i+1)*7:i*8] <= mtime[0][(i+1)*7:i*8];
//                                 end else if (IO_rstrb_i) begin
//                                         mtimeRData[(i+1)*7:i*8] <= mtime[0][(i+1)*7:i*8];
//                                         mtimeData[(i+1)*7:i*8] <= mtime[0][(i+1)*7:i*8];
//                                 end else begin
//                                         mtimeData[(i+1)*7:i*8] <= mtime[0][(i+1)*7:i*8];
//                                 end
//                         end
//                         else if (isMTimeCmp) begin
//                                 if (IO_wstrb_i[i]) begin
//                                         mtime[1][(i+1)*7:i*8] <= IO_wData_i[(i+1)*7:i*8];
//                                         mtimecmpData[(i+1)*7:i*8] <= mtime[1][(i+1)*7:i*8];
//                                 end else if (IO_rstrb_i) begin
//                                         mtimecmpRData[(i+1)*7:i*8] <= mtime[1][(i+1)*7:i*8];
//                                         mtimecmpData[(i+1)*7:i*8] <= mtime[1][(i+1)*7:i*8];
//                                 end else begin
//                                         mtimecmpData[(i+1)*7:i*8] <= mtime[1][(i+1)*7:i*8];
//                                 end
//                         end
//                 end
//
//         end
// endgenerate
//
// always @(posedge rtc_i) begin
//         mtime[0] <= mtime[0] + 1;
// end

/* verilator lint_on MULTIDRIVEN */
/*-------------------------------- QSPI Flash --------------------------------*/
wire flashRstrb = isFlash & IO_rstrb_i;

wire [63:0] SPI_Data;
wire        SPI_Busy;
wire        SPI_valid = ~(SPI_Busy | flashRstrb);

spiFlash flash(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rstrb_i(flashRstrb),
        .raddr_i({IO_addr_i[23:3], 3'b0}),
        .rdata_o(SPI_Data),
        .rbusy_o(SPI_Busy),
        .spiClk_o(spiClk_o),
        .spiCs_o(spiCs_o),
        .spiMosi_io(spiMosi_io),
        .spiMiso_i(spiMiso_i)
        // .spiData_io(spiData_io)
);

/*-------------------------------- UART --------------------------------*/

wire isUartData = isUART & ~IO_addr_i[2];
wire isUartCtrl = isUART & IO_addr_i[2];

wire uartWren = |IO_wstrb_i & isUartData;
wire uartBusy;
wire [31:0] uartRData = isUartData ? 32'b0 : {22'b0, uartBusy, 9'b0};

// 25MHz, 2M baud, 8-bit, no parity, 1 stop bit
localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h00000D};

// 25MHz, 921600 baud, 8-bit, no parity, 1 stop bit
// localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h00001B};

// 100MHz, 115200 baud, 8-bit, no parity, 1 stop bit
// localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h000364};

txuart TXUART (
        .i_clk(clk_i),
        .i_reset(reset_i),
        .i_setup(UART_SETUP),
        .i_break(0),
        .i_wr(uartWren),
        .i_data(IO_wData_i[7:0]),
        .i_cts_n(0),
        .o_uart_tx(txd_o),
        .o_busy(uartBusy)
);

// `ifndef BENCH
// `else
//         assign uartBusy = 1'b0;
//         always @(posedge clk_i) begin
//                 if(uartWren) begin
//                         $write("%c", IO_wData_i[7:0]);
//                         $fflush(32'h8000_0001);
//                 end
//         end
// `endif

/*-------------------------------- Basic IO --------------------------------*/
wire isLED = isBasic & (IO_addr_i[27:3] == 25'h1);

reg [3:0] leds;
always @(posedge clk_i) begin
        if (|IO_wstrb_i) begin
                if (isLED)
                        leds[3:0] <= IO_wData_i[3:0];
        end
end

`ifdef BENCH
        assign leds_o = leds;
`else
        LedDim ledDim (
                .clk(clk_i),
                .leds_i(leds),
                .leds_o(leds_o)
        );
`endif

endmodule

