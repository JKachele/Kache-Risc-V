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
        input  wire [31:0] rvec,

        output wire [3:0] LEDS,
        input  wire RXD,
        output wire TXD,

        output wire qspi_sck,
        output wire qspi_cs,
        inout  wire qspi_mosi,
        input  wire qspi_miso
        // inout  wire [3:0] qspi_dq
);

/*verilator public_flat_rw_on*/
wire clk;
wire reset;
/*verilator public_off*/

// Cache-Memory Interface
wire        IC_mRden;
wire [31:0] IC_mAddr;
wire [63:0] IC_mData;
wire        IC_mValid;

// Instruction Cache
wire        ICacheStrb;
wire        ICacheCancel;
wire [31:0] ICacheAddr;
wire [31:0] ICacheData;
wire        ICacheValid;
wire        ICacheCmp;

// Data Cache
// wire        DCacheStrb;
// wire [31:0] DCacheAddr;
// wire [31:0] DCacheData;
// wire        DCacheValid;

//Memory
wire        DMemRStrb;
wire [31:0] DMemRAddr;
wire [63:0] DMemRData;
wire        DMemRBusy;
wire [31:0] DMemWAddr;
wire [63:0] DMemWData;
wire [7:0]  DMemWMask;
wire        DMemWBusy;
/*verilator public_off*/

Processor CPU(
        .clk_i(clk),
        .reset_i(reset),
        .rvec_i(rvec),
        .ICacheStrb_o(ICacheStrb),
        .ICacheCancel_o(ICacheCancel),
        .ICacheAddr_o(ICacheAddr),
        .ICacheData_i(ICacheData),
        .ICacheValid_i(ICacheValid),
        .ICacheCmp_i(ICacheCmp),
        .DMemRStrb_o(DMemRStrb),
        .DMemRAddr_o(DMemRAddr),
        .DMemRData_i(DMemRData),
        .DMemRBusy_i(DMemRBusy),
        .DMemWAddr_o(DMemWAddr),
        .DMemWData_o(DMemWData),
        .DMemWMask_o(DMemWMask),
        .DMemWBusy_i(DMemWBusy)
);

ICache icache(
        .clk_i(clk),
        .reset_i(reset),
        .addr_i(ICacheAddr),
        .rden_i(ICacheStrb),
        .cancel_i(ICacheCancel),
        .data_o(ICacheData),
        .valid_o(ICacheValid),
        .cmp_o(ICacheCmp),
        .mAddr_o(IC_mAddr),
        .mRden_o(IC_mRden),
        .mData_i(IC_mData),
        .mValid_i(IC_mValid)
);

Memory mem(
        .clk_i(clk),
        .reset_i(reset),
        .rvec_i(rvec),
        .IMemStrb_i(IC_mRden),
        .IMemAddr_i(IC_mAddr),
        .IMemData_o(IC_mData),
        .IMemValid_o(IC_mValid),
        // .IMemStrb_i(ICacheStrb),
        // .IMemAddr_i(ICacheAddr),
        // .IMemData_o(ICacheData),
        // .IMemValid_o(ICacheValid),
        .DMemRStrb_i(DMemRStrb),
        .DMemRAddr_i(DMemRAddr),
        .DMemRData_o(DMemRData),
        .DMemRBusy_o(DMemRBusy),
        .DMemWAddr_i(DMemWAddr),
        .DMemWData_i(DMemWData),
        .DMemWMask_i(DMemWMask),
        .DMemWBusy_o(DMemWBusy),
        .leds_o(LEDS),
        .txd_o(TXD),
        .spiClk_o(qspi_sck),
        .spiCs_o(qspi_cs),
        .spiMosi_io(qspi_mosi),
        .spiMiso_i(qspi_miso)
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

