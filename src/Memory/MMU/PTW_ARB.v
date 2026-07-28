/*************************************************
 *File----------PTW_ARB.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Jul 28, 2026 12:33:15 EDT
 ************************************************/

module PTW_ARB (
        input  wire         clk_i,
        input  wire         reset_i,

        // i-tlb interface
        input  wire [19:0]  i_vpn_i,
        input  wire         i_rden_i,
        input  wire [1:0]   i_priv_i,
        input  wire         i_instr_i,
        input  wire         i_write_i,
        input  wire         i_mxr_i,
        input  wire         i_sum_i,
        input  wire [21:0]  i_ptppn_i,
        output reg  [21:0]  i_ppn_o,
        output reg  [8:0]   i_flags_o,
        output wire         i_valid_o,
        output wire         i_fault_o,

        // d-tlb interface
        input  wire [19:0]  d_vpn_i,
        input  wire         d_rden_i,
        input  wire [1:0]   d_priv_i,
        input  wire         d_instr_i,
        input  wire         d_write_i,
        input  wire         d_mxr_i,
        input  wire         d_sum_i,
        input  wire [21:0]  d_ptppn_i,
        output reg  [21:0]  d_ppn_o,
        output reg  [8:0]   d_flags_o,
        output wire         d_valid_o,
        output wire         d_fault_o,

        // ptw interface
        output reg  [19:0]  ptw_vpn_o,
        output reg          ptw_rden_o,
        output reg  [1:0]   ptw_priv_o,
        output reg          ptw_instr_o,
        output reg          ptw_write_o,
        output reg          ptw_mxr_o,
        output reg          ptw_sum_o,
        output reg  [21:0]  ptw_ptppn_o,
        input  wire [21:0]  ptw_ppn_i,
        input  wire [8:0]   ptw_flags_i,
        input  wire         ptw_valid_i,
        input  wire         ptw_fault_i
);
localparam IDLE  = 2'b0;
localparam I_TLB = 2'b01;
localparam D_TLB = 2'b10;

reg [1:0] arb_sel; // 0 = no requests, 1 = i-tlb, 2 = d-tlb
reg itlb_req;
reg dtlb_req;
reg itlb_valid;
reg dtlb_valid;
reg itlb_fault;
reg dtlb_fault;

assign i_valid_o = itlb_valid;
assign d_valid_o = dtlb_valid;
assign i_fault_o = itlb_fault;
assign d_fault_o = dtlb_fault;

always @(*) begin
        case (arb_sel)
                IDLE: begin
                        ptw_vpn_o     = 20'b0;
                        ptw_priv_o    = 2'b0;
                        ptw_instr_o   = 1'b0;
                        ptw_write_o   = 1'b0;
                        ptw_mxr_o     = 1'b0;
                        ptw_sum_o     = 1'b0;
                        ptw_ptppn_o   = 22'b0;
                        i_ppn_o       = 22'b0;
                        i_flags_o     = 9'b0;
                        d_ppn_o       = 22'b0;
                        d_flags_o     = 9'b0;
                end
                I_TLB: begin
                        ptw_vpn_o     = i_vpn_i;
                        ptw_priv_o    = i_priv_i;
                        ptw_instr_o   = i_instr_i;
                        ptw_write_o   = i_write_i;
                        ptw_mxr_o     = i_mxr_i;
                        ptw_sum_o     = i_sum_i;
                        ptw_ptppn_o   = i_ptppn_i;
                        i_ppn_o       = ptw_ppn_i;
                        i_flags_o     = ptw_flags_i;
                end
                D_TLB: begin
                        ptw_vpn_o     = d_vpn_i;
                        ptw_priv_o    = d_priv_i;
                        ptw_instr_o   = d_instr_i;
                        ptw_write_o   = d_write_i;
                        ptw_mxr_o     = d_mxr_i;
                        ptw_sum_o     = d_sum_i;
                        ptw_ptppn_o   = d_ptppn_i;
                        d_ppn_o       = ptw_ppn_i;
                        d_flags_o     = ptw_flags_i;
                end
        endcase
end

reg [1:0] arb_state = IDLE;

always @(posedge clk_i) begin
        if (reset_i) begin
                arb_state <= IDLE;
                arb_sel       <= IDLE;
                itlb_req      <= 1'b0;
                dtlb_req      <= 1'b0;
                itlb_valid    <= 1'b0;
                dtlb_valid    <= 1'b0;
                itlb_fault    <= 1'b0;
                dtlb_fault    <= 1'b0;
        end else if (arb_state == IDLE) begin
                itlb_valid <= 1'b0;
                dtlb_valid <= 1'b0;
                itlb_fault <= 1'b0;
                dtlb_fault <= 1'b0;
                if (dtlb_req) begin
                        arb_sel <= D_TLB;
                        ptw_rden_o <= 1'b1;
                        arb_state <= D_TLB;
                end else if (itlb_req) begin
                        arb_sel <= I_TLB;
                        ptw_rden_o <= 1'b1;
                        arb_state <= I_TLB;
                end else begin
                        arb_sel <= IDLE;
                        ptw_rden_o <= 1'b0;
                end
        end else if (arb_state == I_TLB) begin
                if (ptw_rden_o) ptw_rden_o <= 1'b0;
                if (ptw_valid_i) begin
                        itlb_valid <= 1'b1;
                        itlb_req   <= 1'b0;
                        arb_state <= IDLE;
                end else if (ptw_fault_i) begin
                        itlb_fault <= 1'b1;
                        itlb_req   <= 1'b0;
                        arb_state <= IDLE;
                end
        end else if (arb_state == D_TLB) begin
                if (ptw_rden_o) ptw_rden_o <= 1'b0;
                if (ptw_valid_i) begin
                        dtlb_valid <= 1'b1;
                        dtlb_req   <= 1'b0;
                        arb_state <= IDLE;
                end else if (ptw_fault_i) begin
                        dtlb_fault <= 1'b1;
                        dtlb_req   <= 1'b0;
                        arb_state <= IDLE;
                end
        end else begin
                arb_state <= IDLE;
        end

        if (i_rden_i & ~reset_i)
                itlb_req <= 1'b1;
        if (d_rden_i & ~reset_i)
                dtlb_req <= 1'b1;
end

endmodule

