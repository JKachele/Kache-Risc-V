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
        output wire clk0_o,   // 100 MHZ
        output wire clk1_o,   // 200 MHZ
        output wire clk2_o,   // 25 MHZ
        output wire clk3_o,   // 3.125 MHZ
        output wire resetn
);

wire clkref_buf;
wire clk_out0;
wire clk_out1;
wire clk_out2;
wire clk_out3;

wire clkfbout;
wire clkfbout_buf;

wire reset_high;
wire locked;


// Input buffering
BUFG BUFG_IN (
        .I (clkref_i),
        .O (clkref_buf)
);

PLLE2_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT        (2),
        .CLKFBOUT_PHASE       (0.000),

        .CLKOUT0_DIVIDE       (2),  // 100 MHZ
        .CLKOUT1_DIVIDE       (1),  // 200 MHZ
        .CLKOUT2_DIVIDE       (8),  // 25 MHZ
        .CLKOUT3_DIVIDE       (64), // 3.125 MHZ

        .CLKOUT0_PHASE        (0.000),
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT2_PHASE        (0.000),
        .CLKOUT3_PHASE        (0.000),

        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        .CLKOUT2_DUTY_CYCLE   (0.500),
        .CLKOUT3_DUTY_CYCLE   (0.500),

        .CLKIN1_PERIOD        (10.000)
) plle2_adv_inst (
        // Output clocks
        .CLKFBOUT            (clkfbout),
        .CLKOUT0             (clk_out0),
        .CLKOUT1             (clk_out1),
        .CLKOUT2             (clk_out2),
        .CLKOUT3             (clk_out3),
        // Input clock control
        .CLKFBIN             (clkfbout_buf),
        .CLKIN1              (clkref_buf),
        .CLKIN2              (1'b0),
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        // Ports for dynamic reconfiguration
        .DADDR               (7'h0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'h0),
        .DWE                 (1'b0),
        // Other control and status signals
        .LOCKED              (locked),
        .PWRDWN              (1'b0),
        .RST                 (~RESET)
);

assign resetn = ~RESET | ~locked;
//--------------------------------------
// Output buffering
//-----------------------------------
BUFG clkf_buf (
        .O (clkfbout_buf),
        .I (clkfbout)
);

assign clk0_o = clk_out0;
assign clk1_o = clk_out1;
assign clk2_o = clk_out2;
assign clk3_o = clk_out3;

endmodule
