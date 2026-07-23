/*************************************************
 *File----------TLB.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jul 23, 2026 16:08:55 EDT
 ************************************************/

module TLB (
        input  wire         clk_i,
        input  wire         reset_i,

        // Cache Interface
        input  wire [19:0]  vpn_i,
        input  wire         flush_i,
        input  wire [8:0]   asid_i,
        input  wire [1:0]   priv_i,
        input  wire         instr_i,
        input  wire         write_i,
        input  wire         vmEnable_i,
        input  wire         rden_i,
        output wire [21:0]  ppn_o,
        output wire         valid_o,

        // Page Table Walker Interface
        output wire [19:0]  ptw_vpn_o,
        output wire [8:0]   ptw_asid_o,
        output wire [1:0]   ptw_priv_o,
        output wire         ptw_instr_o,
        output wire         ptw_write_o,
        output wire         ptw_rden_o,
        input  wire [21:0]  ptw_ppn_i,
        input  wire         ptw_valid_i
);
/*****************************************************************
 * 8-Entry Fully Associative TLB
 * Pseudo-LRU Replacement Policy
 * TLB Entry:
 * 59    51 50     31 30     09  08 07 06 05 04 03 02 01 00
 * *------* *-------* *-------* *-------------------------*
 *   ASID      VPN       PPN     M  D  A  G  U  X  W  R  V
 *                              (M = Mega Page)
 *****************************************************************/
localparam NENTRIES = 8;
localparam ASID_WIDTH = 20;
localparam VPN_WIDTH = 20;
localparam PPN_WIDTH = 22;

`define ASID  59:51
`define VPN   50:31
`define VPN1  50:41
`define VPN0  40:31
`define PPN   30:9
`define PPN1  30:19
`define PPN0  18:9

reg [59:0] tlb_entries [0:NENTRIES-1];

/*-------------------------------- Hit Logic --------------------------------*/
reg [NENTRIES-1:0] tlb_hits_k; // Kilo-page hit
reg [NENTRIES-1:0] tlb_hits_m; // Mega-page hit

wire tlb_hits = tlb_hits_k | tlb_hits_m;
wire tlb_hit_k = |tlb_hits_k;
wire tlb_hit_m = |tlb_hits_m;
wire tlb_hit = |tlb_hits;

integer i;
always @(*) begin
        for (i = 0; i < NENTRIES; i = i + 1) begin
                tlb_hits_k[i] = (tlb_entries[i][`ASID] == asid_i) &&
                                (tlb_entries[i][`VPN] == vpn_i) &&
                                (tlb_entries[i][8] == 1'b0) && // Mega-page bit
                                (tlb_entries[i][0] == 1'b1);   // Valid bit
                tlb_hits_m[i] = (tlb_entries[i][`ASID] == asid_i) &&
                                (tlb_entries[i][`VPN1] == vpn_i[19:10]) &&
                                (tlb_entries[i][8] == 1'b1) && // Mega-page bit
                                (tlb_entries[i][0] == 1'b1); // Valid bit
        end
end

reg hit_idx;
reg found;

integer j;
always @(*) begin
        hit_idx = 0;
        found = 0;
        for (j = 0; j < NENTRIES; j = j + 1) begin
                if (tlb_hits[j]) begin
                        hit_idx = j;
                        found = 1;
                end
        end
end

reg [21:0] ppn_r;
assign ppn_o = ppn_r;
always @(*) begin
        if (C_curState != IDLE) begin
                ppn_r = 22'b0;
        end else if (tlb_hit_k) begin
                ppn_r = tlb_entries[hit_idx][`PPN];
        end else if (tlb_hit_m) begin
                ppn_r = {tlb_entries[hit_idx][`PPN1], vpn_i[9:0]};
        end else begin
                ppn_r = 22'b0;
        end
end

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE = 1'b0;
localparam MISS = 1'b1;

reg C_curState = IDLE;

endmodule

