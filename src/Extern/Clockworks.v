/*************************************************
 *File----------Clockworks.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Sunday Nov 02, 2025 13:25:08 EST
 *License-------GNU GPL-3.0
 ************************************************/

module Clockworks
(
        input  wire CLK, // clock pin of the board
        input  wire RESET, // reset pin of the board
        output wire clk,   // (optionally divided) clock for the design.
        // divided if SLOW is different from zero.
        output wire resetn // (optionally timed) negative reset for the design
);

parameter SLOW=0;

generate

        if (SLOW != 0) begin : g_slow
                // Slow clock down by 2^SLOW
                reg [SLOW:0] slow_CLK = 0;
                always @(posedge CLK) begin
                        slow_CLK <= slow_CLK + 1;
                end
                assign clk = slow_CLK[SLOW-1];
        end else begin : g_same
                assign clk = CLK;
        end
        `ifdef BENCH
                assign resetn = RESET;
        `else
                assign resetn = !RESET;
        `endif

endgenerate
endmodule

module ClockworksA7 (
        input  wire clkref_i,
        input  wire RESET,
        output wire clk0_o,
        output wire clk1_o,
        output wire clk2_o,
        output wire resetn
);


wire clkref_buffered_w;
wire clkfbout_w;
wire clkfbout_buffered_w;
wire pll_clkout0_w;
wire pll_clkout0_buffered_w;
wire pll_clkout1_w;
wire pll_clkout1_buffered_w;
wire pll_clkout2_w;
wire pll_clkout2_buffered_w;
wire locked;

// Input buffering
BUFG BUFG_IN (
        .I (clkref_i),
        .O (clkref_buffered_w)
);

// Clocking primitive
PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),      // OPTIMIZED, HIGH, LOW
        .CLKFBOUT_PHASE(0.0),         // Phase offset in degrees of CLKFB, (-360-360)
        .CLKIN1_PERIOD(10.0),         // Input clock period in ns resolution
        .CLKFBOUT_MULT(10),     // VCO=1GHz

        // CLKOUTx_DIVIDE: Divide amount for each CLKOUT(1-128)
        .CLKOUT0_DIVIDE(10), // CLK0=100MHz
        .CLKOUT1_DIVIDE(5), // CLK1=200MHz
        .CLKOUT2_DIVIDE(40), // CLK2=25MHz

        // CLKOUTx_DUTY_CYCLE: Duty cycle for each CLKOUT
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DUTY_CYCLE(0.5),

        // CLKOUTx_PHASE: Phase offset for each CLKOUT
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_PHASE(0.0),
        .CLKOUT2_PHASE(0.0),

        .DIVCLK_DIVIDE(1),            // Master division value (1-56)
        .REF_JITTER1(0.0),            // Ref. input jitter in UI (0.000-0.999)
        .STARTUP_WAIT("TRUE")         // Delay DONE until PLL Locks ("TRUE"/"FALSE")
) u_pll (
        .CLKFBOUT(clkfbout_w),
        .CLKOUT0(pll_clkout0_w),
        .CLKOUT1(pll_clkout1_w),
        .CLKOUT2(pll_clkout2_w),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(1'b0),
        .CLKIN1(clkref_buffered_w),
        .CLKFBIN(clkfbout_buffered_w)
);

BUFH u_clkfb_buf (
        .I(clkfbout_w),
        .O(clkfbout_buffered_w)
);


//-----------------------------------------------------------------
// Reset
//-----------------------------------------------------------------
assign resetn = ~RESET | ~locked;


//-----------------------------------------------------------------
// CLK_OUT0
//-----------------------------------------------------------------
assign pll_clkout0_buffered_w = pll_clkout0_w;

assign clk0_o = pll_clkout0_buffered_w;


//-----------------------------------------------------------------
// CLK_OUT1
//-----------------------------------------------------------------
assign pll_clkout1_buffered_w = pll_clkout1_w;

assign clk1_o = pll_clkout1_buffered_w;


//-----------------------------------------------------------------
// CLK_OUT2
//-----------------------------------------------------------------
assign pll_clkout2_buffered_w = pll_clkout2_w;

assign clk2_o = pll_clkout2_buffered_w;

endmodule
