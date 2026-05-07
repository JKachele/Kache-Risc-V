/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module SOC (
        input  wire CLK,
        input  wire RESET,
        output wire [3:0] LEDS,
        input  wire RXD,
        output wire TXD,

        output wire qspi_sck,
        output wire qspi_cs,
        inout  wire [3:0] qspi_dq
);

/*verilator public_flat_rw_on*/
wire clk;
wire reset;
/*verilator public_off*/

//Memory
wire [31:0] IMemAddr;
wire [63:0] IMemData;
wire [31:0] DMemRAddr;
wire [31:0] DMemRData;
wire [31:0] DMemWAddr;
wire [31:0] DMemWData;
wire [3:0]  DMemWMask;

// IO
wire [31:0] IO_memRAddr;
wire [31:0] IO_memRData;
wire [31:0] IO_memWAddr;
wire [31:0] IO_memWData;
wire        IO_memWr;

Processor CPU(
        .clk_i(clk),
        .reset_i(reset),
        .IMemAddr_o(IMemAddr),
        .IMemData_i(IMemData),
        .DMemRAddr_o(DMemRAddr),
        .DMemRData_i(DMemRData),
        .DMemWAddr_o(DMemWAddr),
        .DMemWData_o(DMemWData),
        .DMemWMask_o(DMemWMask)
);

Memory mem(
        .clk_i(clk),
        .reset_i(reset),
        .IMemAddr_i(IMemAddr),
        .IMemData_o(IMemData),
        .DMemRAddr_i(DMemRAddr),
        .DMemRData_o(DMemRData),
        .DMemWAddr_i(DMemWAddr),
        .DMemWData_i(DMemWData),
        .DMemWMask_i(DMemWMask),
        .leds_o(LEDS),
        .txd_o(TXD)
);

Clockworks #(
`ifdef BENCH
        .SLOW(0)
`else
        .SLOW(2)        // Slow clock by 2^SLOW
`endif
)CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

endmodule
/* verilator lint_on WIDTH */

