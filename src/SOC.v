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
wire         IC_mRden;
wire [31:0]  IC_mAddr;
wire [255:0] IC_mData;
wire         IC_mValid;
wire [31:0]  DC_mAddr;
wire         DC_mRden;
wire [63:0]  DC_mWData;
wire [7:0]   DC_mWren;
wire [63:0]  DC_mRData;
wire         DC_mValidReady;

// Instruction Cache
wire        ICacheStrb;
wire        ICacheCancel;
wire [31:0] ICacheAddr;
wire [31:0] ICacheData;
wire        ICacheValid;
wire        ICacheCmp;

// Data Cache
wire [31:0] DCacheAddr;
wire        DCacheRden;
wire [63:0] DCacheWData;
wire [7:0]  DCacheWren;
wire [63:0] DCacheRData;
wire        DCacheValidReady;

//Memory
wire [31:0] DMemAddr;
wire        DMemRStrb;
wire [63:0] DMemRData;
wire [63:0] DMemWData;
wire [7:0]  DMemWMask;
wire        DMemValidReady;
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
        .DMemAddr_o(DCacheAddr),
        .DMemRStrb_o(DCacheRden),
        .DMemWData_o(DCacheWData),
        .DMemWMask_o(DCacheWren),
        .DMemRData_i(DCacheRData),
        .DMemValidReady_i(DCacheValidReady)
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

DCache dcache(
        .clk_i(clk),
        .reset_i(reset),
        .addr_i(DCacheAddr),
        .rden_i(DCacheRden),
        .wdata_i(DCacheWData),
        .wren_i(DCacheWren),
        .rdata_o(DCacheRData),
        .validReady_o(DCacheValidReady),
        .mAddr_o(DC_mAddr),
        .mWData_o(DC_mWData),
        .mRden_o(DC_mRden),
        .mWren_o(DC_mWren),
        .mRData_i(DC_mRData),
        .mValidReady_i(DC_mValidReady)
);

Memory mem(
        .clk_i(clk),
        .reset_i(reset),
        .rvec_i(rvec),
        .IMemStrb_i(IC_mRden),
        .IMemAddr_i(IC_mAddr),
        .IMemData_o(IC_mData),
        .IMemValid_o(IC_mValid),
        .DMemAddr_i(DC_mAddr),
        .DMemRStrb_i(DC_mRden),
        .DMemWData_i(DC_mWData),
        .DMemWMask_i(DC_mWren),
        .DMemRData_o(DC_mRData),
        .DMemValidReady_o(DC_mValidReady),
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

