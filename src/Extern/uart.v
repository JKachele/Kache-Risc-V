/*************************************************
 *File----------uart.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Aug 17, 2026 11:58:52 EDT
 ************************************************/

module uart #(
        parameter [23:0]   ClkPerBaud
)(
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire        wren_i,
        input  wire [7:0]  txData_i,
        input  wire        rden_i,
        output reg  [7:0]  rxData_o,
        output reg         txFull_o,    // Transmit FIFO Full
        output reg         rxReady_o,   // Receive FIFO Data Present

        input  wire        rxd_i,
        output wire        txd_o
);
localparam [23:0]  HALF_BAUD = ClkPerBaud / 2;

localparam IDLE  = 2'b00;
localparam START = 2'b01;
localparam DATA  = 2'b10;
localparam STOP  = 2'b11;


reg [7:0] rxDataFIFO [0:15];
reg [7:0] txDataFIFO [0:15];
reg [3:0] rxReadPtr  = 4'b0;
reg [3:0] rxWritePtr = 4'b0;
reg [3:0] txReadPtr  = 4'b0;
reg [3:0] txWritePtr = 4'b0;

/*-------------------------------- Transmit --------------------------------*/
reg txd_r = 1'b1;
assign txd_o = txd_r;

// Write new data to FIFO
always @(posedge clk_i) begin
        if (reset_i) begin
                txReadPtr <= 4'b0;
                txWritePtr <= 4'b0;
        end else if (wren_i) begin
                txDataFIFO[txWritePtr] <= txData_i;
                txWritePtr <= txWritePtr + 4'b0001;
                if (txWritePtr == txReadPtr)
                        txFull_o <= 1'b1;
        end

        if (txWritePtr != txReadPtr)
                txFull_o <= 1'b0;
end

// Transmit data from FIFO
reg [1:0]  txState = IDLE;
reg [23:0] txBaudCount = 24'b0;

reg [7:0]  txShiftReg = 8'b0;
reg [2:0]  txShiftCount = 3'b0;

always @(posedge clk_i) begin
        if (reset_i) begin
                txState      <= IDLE;
                txBaudCount  <= 24'b0;
                txShiftReg   <= 8'b0;
                txShiftCount <= 3'b0;
        end else if (txBaudCount == 24'b0) begin
                if (txState == IDLE) begin
                        if (txReadPtr != txWritePtr || txFull_o) begin
                                // Read data from fifo
                                txShiftReg <= txDataFIFO[txReadPtr];
                                txReadPtr <= txReadPtr + 4'b0001;
                                // Set shift count
                                txShiftCount <= 3'd7;
                                // Set baud counter
                                txBaudCount <= ClkPerBaud - 1'b1;
                                // Send start-bit
                                txd_r <= 1'b0;
                                // Move to data state
                                txState <= DATA;
                        end else begin
                                txd_r <= 1'b1;
                        end
                end else if (txState == DATA) begin
                        // Send data bit
                        txd_r <= txShiftReg[0];
                        // Shift data
                        txShiftReg <= {1'b0, txShiftReg[7:1]};
                        // Decrement shift count
                        if (txShiftCount == 3'b0)
                                txState <= STOP;
                        else
                                txShiftCount <= txShiftCount - 1'b1;
                        // Set baud counter
                        txBaudCount <= ClkPerBaud - 1'b1;
                end else begin // txState == STOP
                        // Send stop bit and return to idle
                        txd_r <= 1'b1;
                        txState <= IDLE;
                        txBaudCount <= ClkPerBaud - 1'b1;
                end
        end else begin
                        txBaudCount <= txBaudCount - 1;
        end
end

/*-------------------------------- Receive --------------------------------*/

// Read new data from FIFO
always @(posedge clk_i) begin
        if (reset_i) begin
                rxReadPtr <= 4'b0;
                rxWritePtr <= 4'b0;
        end else if (rden_i) begin
                if (rxReadPtr != rxWritePtr) begin
                        rxData_o <= rxDataFIFO[rxReadPtr];
                        rxReadPtr <= rxReadPtr + 4'b0001;
                end else begin
                        rxData_o <= 8'b0;
                end
        end

        if (rxReadPtr != rxWritePtr)
                rxReady_o <= 1'b1;
        else
                rxReady_o <= 1'b0;
end

// Revieve data from UART
reg [1:0]  rxState = IDLE;
reg [23:0] rxBaudCount = 24'b0;

reg [7:0]  rxShiftReg = 8'b0;
reg [2:0]  rxShiftCount = 3'b0;

always @(posedge clk_i) begin
        if (reset_i) begin
                rxState      <= IDLE;
                rxBaudCount  <= 24'b0;
                rxShiftReg   <= 8'b0;
                rxShiftCount <= 3'b0;
        end else if (rxBaudCount == 24'b0) begin
                if (rxState == IDLE) begin
                        if (rxd_i == 1'b0) begin
                                rxBaudCount <= HALF_BAUD - 1'b1;
                                rxState <= START;
                        end
                end else if (rxState == START) begin
                        rxBaudCount <= ClkPerBaud - 1'b1;
                        rxShiftCount <= 3'd7;
                        rxState <= DATA;
                end else if (rxState == DATA) begin
                        rxShiftReg <= {rxd_i, rxShiftReg[7:1]};
                        if (rxShiftCount == 3'b0) begin
                                rxState <= STOP;
                        end else begin
                                rxShiftCount <= rxShiftCount - 1'b1;
                        end
                        rxBaudCount <= ClkPerBaud - 1'b1;
                end else begin // rxState == STOP
                        rxDataFIFO[rxWritePtr] <= rxShiftReg;
                        rxWritePtr <= rxWritePtr + 4'b0001;
                        rxState <= IDLE;
                end
        end else begin
                rxBaudCount <= rxBaudCount - 1;
        end
end

endmodule

