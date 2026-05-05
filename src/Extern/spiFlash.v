/*************************************************
 *File----------spiFlash.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday May 05, 2026 17:05:21 UTC
 ************************************************/

// SPI Read Dual Output
module spiFlash (
        input  wire        clk_i,
        input  wire        rstrb_i,
        input  wire [23:0] raddr_i,

        output wire [31:0] rdata_o,
        output wire        rbusy_o,

        output wire        spiClk_o,
        output reg         spiCs_o,
        inout  wire [3:0]  spiData_io
);

// Only MOSI (spiData_io[0]) is used for output so will set the other lines to high impedence
assign spiData_io[3:1] = 3'bzzz;

wire MOSI_out;
wire MOSI_in;
wire MOSI_oe;

assign spiData_io[0] = MOSI_oe ? MOSI_out : 1'bz;
assign MOSI_in = spiData_io[0];

reg [5:0]  snd_count;
reg [31:0] snd_data;
reg [5:0]  rcv_count;
reg [31:0] rvc_data;

wire sending   = (snd_count != 0);
wire receiving = (rcv_count != 0);
wire busy      = (sending | receiving);
assign rbusy_o = !spiCs_o;

assign MOSI_oe = !receiving;
assign MOSI_out = sending && snd_data[31];

initial spiCs_o = 1'b1;
assign spiClk_o = !spiCs_o && !clk_i;

assign rdata_o = {rcv_data[7:0], rcv_data[15:8], rcv_data[23:16], rcv_data[31:24]};

always @(posedge clk_i) begin
        if (rstrb_i) begin
                spiCs_o <= 1'b0;
                snd_data = {8'h3B, raddr_i};
                snd_count <= 6'd40; // 8-bit command, 24-bit address, 8 dummy clocks
        end else begin
                if (sending) begin
                        if (snd_count == 1)
                                rcv_count <= 6'd32;
                        snd_count <= snd_count - 1;
                        snd_data <= {snd_data[30:0], 1'b1};
                end
                if (receiving) begin
                        rcv_count <= rcv_count - 1;
                        rcv_data <= {rcv_data[29:0], spiData_io[1:0]};
                end
                if (!busy) begin
                        spiCs_o <= 1'b1;
                end
        end
end

endmodule

// SPI Read Quad Output
module spiQFlash (
        input  wire        clk_i,
        input  wire        rstrb_i,
        input  wire [23:0] raddr_i,

        output wire [31:0] rdata_o,
        output wire        rbusy_o,

        output wire        spiClk_o,
        output reg         spiCs_o,
        inout  wire [3:0]  spiData_io
);

// Only MOSI (spiData_io[0]) is used for output so will set the other lines to high impedence
assign spiData_io[3:1] = 3'bzzz;

wire MOSI_out;
wire MOSI_in;
wire MOSI_oe;

assign spiData_io[0] = MOSI_oe ? MOSI_out : 1'bz;
assign MOSI_in = spiData_io[0];

reg [5:0]  snd_count;
reg [31:0] snd_data;
reg [5:0]  rcv_count;
reg [31:0] rvc_data;

wire sending   = (snd_count != 0);
wire receiving = (rcv_count != 0);
wire busy      = (sending | receiving);
assign rbusy_o = !spiCs_o;

assign MOSI_oe = !receiving;
assign MOSI_out = sending && snd_data[31];

initial spiCs_o = 1'b1;
assign spiClk_o = !spiCs_o && !clk_i;

assign rdata_o = {rcv_data[7:0], rcv_data[15:8], rcv_data[23:16], rcv_data[31:24]};

always @(posedge clk_i) begin
        if (rstrb_i) begin
                spiCs_o <= 1'b0;
                snd_data = {8'h6B, raddr_i};
                snd_count <= 6'd40;
        end else begin
                if (sending) begin
                        if (snd_count == 1)
                                rcv_count <= 6'd32;
                        snd_count <= snd_count - 1;
                        snd_data <= {snd_data[30:0], 1'b1};
                end
                if (receiving) begin
                        rcv_count <= rcv_count - 1;
                        rcv_data <= {rcv_data[27:0], spiData_io};
                end
                if (!busy) begin
                        spiCs_o <= 1'b1;
                end
        end
end

endmodule

