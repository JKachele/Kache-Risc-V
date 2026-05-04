/*************************************************
 *File----------FSQRT.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 22, 2025 13:51:51 UTC
 ************************************************/

module FSQRT #(
        parameter FLEN = 32
)(
        input  wire                     clk_i,
        input  wire                     reset_i,
        input  wire                     sqrtEnable_i,

        input  wire        [FLEN-1:0]   rs1_i,
        input  wire signed [NEXP+1:0]   rs1Exp_i,
        input  wire        [NSIG:0]     rs1Sig_i,
        input  wire        [5:0]        rs1Class_i,
        input  wire        [2:0]        rm_i,

        output reg                      ready_o,
        output wire        [FLEN-1:0]   fsqrtOut_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

localparam NEXP      = (FLEN == 32) ? 8 : 11;
localparam NSIG      = (FLEN == 32) ? 23 : 52;
localparam EMAX = ((1 << (NEXP - 1)) - 1);
localparam BIAS = EMAX;
localparam EMIN = 1 - EMAX;

reg [FLEN-1:0] sqrtOut;
assign fsqrtOut_o = sqrtOut;

// Working registers
reg signed [NEXP+1:0]  expIn;
reg signed [NEXP+1:0]  qExp;
reg [NSIG+2:0] sqrtSig;
reg [NSIG+2:0] sqrtIn;

reg [NSIG+2:0] x;
reg [NSIG+2:0] xNext;
reg [NSIG+2:0] q;
reg [NSIG+2:0] qNext;
reg [NSIG+4:0] ac;
reg [NSIG+4:0] acNext;
reg [NSIG+4:0] test;

// Cycle counter
reg  [5:0] counter;
// Only one cycle is needed to handle special cases
localparam SPECIAL_CYCLES = 6'd1;
// Enough cycles to compute full significand with extra bits for rounding and normalizing
localparam SQRT_CYCLES = NSIG + 3;

// Status Flags
reg special;    // Special Cases (NaN, inf, zero)
reg busy;

// A wire set to infinity or the max normal number depending on rounding modes
wire si = (rm_i == 3'b001 || rm_i == 3'b010);
wire [FLEN-1:0] roundedInfinity = {1'b0, {NEXP-1{1'b1}}, ~si, {NSIG{si}}};

// Rounding
localparam  ROUND_LEN = (NSIG + 3) * 2;
reg         [ROUND_LEN-1:0] rootIn;
wire        [NSIG:0] sigOut;
wire signed [NEXP+1:0]  expOut;
FRound #(.NINT(ROUND_LEN), .NEXP(NEXP), .NSIG(NSIG))round(
        .sign_i(1'b0), .sig_i(rootIn), .exp_i(expIn),
        .rm_i(rm_i), .sig_o(sigOut), .exp_o(expOut));

always @(posedge clk_i) begin
        if (!sqrtEnable_i) begin
                counter <= 0;
        end else if (counter == 0 && !reset_i) begin
                // Treat special cases as default
                special <= 1'b1;
                counter <= SPECIAL_CYCLES;

                // initalize output
                sqrtOut = 0;

                /************************ Special Cases ************************/
                // Propagate NaN and Zero (Zero keeps original sign)
                if (|(rs1Class_i & 6'b110001)) begin
                        sqrtOut = rs1_i;
                end
                // Negatives are invalid and return qNaN
                else if (rs1_i[FLEN-1]) begin
                        sqrtOut = {1'b0, {FLEN-1{1'b1}}};
                end
                // Infinity returns infinity
                else if (rs1Class_i[CLASS_BIT_INF]) begin
                        sqrtOut = rs1_i;
                end
                // Normal and subnormal numbers proceed to sqrt algorithm
                else begin
                        special <= 1'b0;
                        counter <= SQRT_CYCLES;

                        // Exponent gets halved
                        expIn <= {rs1Exp_i[NEXP+1], rs1Exp_i[NEXP+1:1]};

                        // Input into square root is significand with hidden bit
                        // If rs1Exp_i is odd, right shift by 1
                        q = 0;
                        sqrtSig = {1'b0, rs1Sig_i, 1'b0} >> rs1Exp_i[0];
                        {ac, x} = {{NSIG+3{1'b0}}, sqrtSig, 2'b0};

                        sqrtOut = {{NEXP-2{1'b0}}, q};
                end
        end else if (counter > 2) begin
                counter <= counter - 1;

                x <= xNext;
                ac <= acNext;
                q <= qNext;

                sqrtOut <= {{NEXP-2{1'b0}}, qNext};
        end else if (counter > 1) begin
                counter <= counter - 1;

                rootIn <= (rs1Exp_i[0]) ? {qNext[NSIG:0], acNext[NSIG+4:0]} :
                        {qNext[NSIG+1:1], acNext[NSIG+4:0]};
        end else if (counter > 0) begin // Construct final output
                counter <= counter - 1;

                // Special cases already constructed output
                if (~special) begin
                        // Zero
                        if (~|sigOut) begin
                                // Negative zero if rounding mode is towards -infinity
                                sqrtOut <= {rm_i == 3'b010, {FLEN-1{1'b0}}};
                        end
                        // Underflow
                        else if (expOut < (EMIN - NSIG - 1)) begin
                                sqrtOut <= {FLEN{1'b0}};
                        end
                        // Subnormal
                        else if (expOut < EMIN) begin
                                sqrtOut <= {{NEXP+1{1'b0}}, sigOut[NSIG-1:0]};
                        end
                        // Overflow
                        else if (expOut > EMAX) begin
                                sqrtOut <= roundedInfinity;
                        end
                        // Normal
                        else begin
                                qExp = expOut + BIAS;
                                sqrtOut = {1'b0, qExp[NEXP-1:0], sigOut[NSIG-1:0]};
                        end
                end
                special <= 1'b0;
        end
end

always @(*) begin
        test = ac - {q, 2'b01};
        if (test[NSIG+4] == 0) begin
                {acNext, xNext} = {test[NSIG+2:0], x, 2'b0};
                qNext = {q[NSIG+1:0], 1'b1};
        end else begin
                {acNext, xNext} = {ac[NSIG+2:0], x, 2'b0};
                qNext = q << 1;
        end
end

// Logic to generate the busy signal
always @(negedge clk_i) begin
        if (counter > 0) begin
                busy <= 1'b1;
                ready_o <= 1'b0;
        end else if (busy) begin
                busy <= 1'b0;
                ready_o <= 1'b1;
        end else begin
                ready_o <= 1'b0;
        end
end
endmodule

