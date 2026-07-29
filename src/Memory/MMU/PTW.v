/*************************************************
 *File----------MMU_PTW.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Jul 27, 2026 17:32:36 EDT
 ************************************************/

module PTW (
        input  wire        clk_i,
        input  wire        reset_i,

        // i-tlb interface
        input  wire [19:0] i_vpn_i,
        input  wire        i_rden_i,
        input  wire [1:0]  i_priv_i,
        input  wire        i_instr_i,
        input  wire        i_write_i,
        input  wire        i_mxr_i,
        input  wire        i_sum_i,
        input  wire [21:0] i_ptppn_i,
        output wire [21:0] i_ppn_o,
        output wire [8:0]  i_flags_o,
        output wire        i_valid_o,
        output wire        i_fault_o,

        // d-tlb interface
        input  wire [19:0] d_vpn_i,
        input  wire        d_rden_i,
        input  wire [1:0]  d_priv_i,
        input  wire        d_instr_i,
        input  wire        d_write_i,
        input  wire        d_mxr_i,
        input  wire        d_sum_i,
        input  wire [21:0] d_ptppn_i,
        output wire [21:0] d_ppn_o,
        output wire [8:0]  d_flags_o,
        output wire        d_valid_o,
        output wire        d_fault_o,

        // Data Mem Interface
        output wire [31:0] DMemAddr_o,
        output wire        DMemRden_o,
        output wire [63:0] DMemWData_o,
        output wire [7:0]  DMemWren_o,
        input  wire [63:0] DMemRData_i,
        input  wire        DMemValidReady_i
);

/*-------------------------------- Arbiter --------------------------------*/
wire [19:0]  ptw_vpn;
wire         ptw_rden;
wire [1:0]   ptw_priv;
wire         ptw_instr;
wire         ptw_write;
wire         ptw_mxr;
wire         ptw_sum;
wire [21:0]  ptw_ptppn;
reg  [21:0]  ptw_ppn;
reg  [8:0]   ptw_flags;
wire         ptw_valid;
wire         ptw_fault;

PTW_ARB arb(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .i_vpn_i(i_vpn_i),
        .i_rden_i(i_rden_i),
        .i_priv_i(i_priv_i),
        .i_instr_i(i_instr_i),
        .i_write_i(i_write_i),
        .i_mxr_i(i_mxr_i),
        .i_sum_i(i_sum_i),
        .i_ptppn_i(i_ptppn_i),
        .i_ppn_o(i_ppn_o),
        .i_flags_o(i_flags_o),
        .i_valid_o(i_valid_o),
        .i_fault_o(i_fault_o),
        .d_vpn_i(d_vpn_i),
        .d_rden_i(d_rden_i),
        .d_priv_i(d_priv_i),
        .d_instr_i(d_instr_i),
        .d_write_i(d_write_i),
        .d_mxr_i(d_mxr_i),
        .d_sum_i(d_sum_i),
        .d_ptppn_i(d_ptppn_i),
        .d_ppn_o(d_ppn_o),
        .d_flags_o(d_flags_o),
        .d_valid_o(d_valid_o),
        .d_fault_o(d_fault_o),
        .ptw_vpn_o(ptw_vpn),
        .ptw_rden_o(ptw_rden),
        .ptw_priv_o(ptw_priv),
        .ptw_instr_o(ptw_instr),
        .ptw_write_o(ptw_write),
        .ptw_mxr_o(ptw_mxr),
        .ptw_sum_o(ptw_sum),
        .ptw_ptppn_o(ptw_ptppn),
        .ptw_ppn_i(ptw_ppn),
        .ptw_flags_i(ptw_flags),
        .ptw_valid_i(ptw_valid),
        .ptw_fault_i(ptw_fault)
);

/*-------------------------------- Page Table Walker --------------------------------*/
localparam IDLE     = 3'b000;
localparam REQ      = 3'b001;
localparam READ_PT  = 3'b010;
localparam WRITE_PT = 3'b011;
localparam DONE     = 3'b100;
localparam FAULT    = 3'b101;

assign ptw_valid = (ptw_state == DONE);
assign ptw_fault = (ptw_state == FAULT);

reg [21:0] pt_ppn   = 22'b0;
reg        pt_level = 1'b1;
reg        DMemRden = 1'b0;
reg        pteWren  = 1'b0;
reg [31:0] pteWData = 32'b0;
assign DMemAddr_o = {pt_ppn[19:0], pt_level ? ptw_vpn[19:10] : ptw_vpn[9:0], 2'b00};
assign DMemRden_o = DMemRden;
assign DMemWData_o = DMemAddr_o[2] ? {pteWData, 32'b0} : {32'b0, pteWData};
assign DMemWren_o = pteWren ? (DMemAddr_o[2] ? 8'hF0 : 8'h0F) : 8'b0;

wire [31:0] pte       = DMemAddr_o[2] ? DMemRData_i[63:32] : DMemRData_i[31:0];
wire [21:0] pte_ppn   = pte[31:10];
wire        pte_valid = pte[0] & ~(~pte[1] & pte[2]); // Writable must be readable
wire        pte_leaf  = |pte[3:1];
wire        pte_priv_allow = (pte[4] & ((ptw_priv == 2'b00) | (ptw_priv == 2'b01 & ptw_sum)) |
                                (~pte[4] & (ptw_priv == 2'b01)));
wire        pte_rwx_allow = (ptw_instr & pte[3]) | (ptw_write & pte[2]) |
                                (~ptw_instr & ~ptw_write & (pte[1] | (ptw_mxr & pte[3])));

reg [2:0] ptw_state = IDLE;

always @(posedge clk_i) begin
        if (reset_i) begin
                ptw_state <= IDLE;
                pt_level  <= 1'b1;
                DMemRden  <= 1'b0;
                pteWren   <= 1'b0;
                pteWData  <= 32'b0;
                ptw_ppn   <= 22'b0;
                ptw_flags <= 9'b0;
        end else if (ptw_state == IDLE) begin
                if (ptw_rden) begin
                        pt_ppn <= ptw_ptppn;
                        pt_level <= 1'b1;
                        ptw_state <= REQ;
                end
        end else if (ptw_state == REQ) begin
                DMemRden  <= 1'b1;
                ptw_state <= READ_PT;
        end else if (ptw_state == READ_PT) begin
                if (DMemValidReady_i) begin
                        DMemRden  <= 1'b0;
                        if (~pte_valid) begin
                                ptw_state <= FAULT;
                        end else if (pte_leaf) begin
                                // Misaligned Mega Page
                                if (pt_level & |pte_ppn[9:0]) begin
                                        ptw_state <= FAULT;
                                end
                                // Check Privilege and Access Rights
                                else if (~pte_priv_allow | ~pte_rwx_allow) begin
                                        ptw_state <= FAULT;
                                end
                                // Set accessed and Dirty bits if needed
                                else if (~pte[6] | (~pte[7] & ptw_write)) begin
                                        pteWData <= pte | {24'b0, ptw_write, 1'b1, 6'b0};
                                        pteWren <= 1'b1;
                                        ptw_state <= WRITE_PT;
                                end
                                // Mega Page
                                else if (pt_level) begin
                                        ptw_ppn <= {pte_ppn[21:10], ptw_vpn[9:0]};
                                        ptw_flags <= {1'b1, pte[7:0]};
                                        ptw_state <= DONE;
                                end
                                // Normal Page
                                else begin
                                        ptw_ppn <= pte_ppn;
                                        ptw_flags <= {1'b0, pte[7:0]};
                                        ptw_state <= DONE;
                                end
                        end else begin
                                if (pt_level) begin
                                        pt_ppn <= pte_ppn;
                                        pt_level <= 1'b0;
                                        ptw_state <= REQ;
                                end else begin
                                        ptw_state <= FAULT;
                                end
                        end
                end
        end else if (ptw_state == WRITE_PT) begin
                if (DMemValidReady_i) begin
                        pteWren <= 1'b0;
                        DMemRden  <= 1'b1;
                        ptw_state <= REQ;
                end
        end else if (ptw_state == DONE) begin
                ptw_state <= IDLE;
        end else if (ptw_state == FAULT) begin
                ptw_state <= IDLE;
        end else begin
                ptw_state <= IDLE;
        end
end

endmodule

