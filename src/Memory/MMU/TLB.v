/*************************************************
 *File----------TLB.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jul 23, 2026 16:08:55 EDT
 ************************************************/

module TLB (
        input  wire        clk_i,
        input  wire        reset_i,

        // Cache Interface
        input  wire [19:0] vpn_i,
        input  wire [8:0]  asid_i,
        input  wire        rden_i,
        input  wire        flush_i,
        input  wire [1:0]  priv_i,
        input  wire        instr_i,
        input  wire        write_i,
        input  wire        mxr_i, // Make eXecutable Readable
        input  wire        sum_i, // permit Supervisor User Memory access
        input  wire        vmEnable_i,
        input  wire [21:0] ptppn_i, // Page Table Root Physical Page Number
        input  wire        cancel_i,
        output wire [21:0] ppn_o,
        output wire        valid_o,

        // Page Table Walker Interface
        output wire [19:0] ptw_vpn_o,
        output wire        ptw_rden_o,
        output wire [1:0]  ptw_priv_o,
        output wire        ptw_instr_o,
        output wire        ptw_write_o,
        output wire        ptw_mxr_o,
        output wire        ptw_sum_o,
        output wire [21:0] ptw_ptppn_o,
        input  wire [21:0] ptw_ppn_i,
        input  wire [8:0]  ptw_flags_i,
        input  wire        ptw_valid_i,
        input  wire        ptw_fault_i
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
localparam IDX_SIZE = $clog2(NENTRIES);
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
reg       lru0;
reg [1:0] lru1;
reg [3:0] lru2;
/*              1       lru0           0
 *      1    lru1[1]  0          1  lru1[0]   0
 *   lru2[3]       lru2[2]     lru2[1]     lru2[0]
 */
wire [IDX_SIZE-1:0] lru_idx = {lru0,
        lru0 ? lru1[1] : lru1[0],
        lru0 ? (lru1[1] ? lru2[3] : lru2[2]) : (lru1[0] ? lru2[1] : lru2[0])};

/*-------------------------------- Hit Logic --------------------------------*/
reg [NENTRIES-1:0] tlb_hits_k; // Kilo-page hit
reg [NENTRIES-1:0] tlb_hits_m; // Mega-page hit

wire tlb_hits = tlb_hits_k | tlb_hits_m;
wire tlb_hit_k = |tlb_hits_k;
wire tlb_hit_m = |tlb_hits_m;
wire tlb_hit = |tlb_hits;

always @(*) begin: tlb_hit_logic
        for (integer i = 0; i < NENTRIES; i = i + 1) begin
                                // Only need to check ASID if global bit is not set
                tlb_hits_k[i] = ((tlb_entries[i][`ASID] == asid_i) || (tlb_entries[i][5])) &&
                                (tlb_entries[i][`VPN] == vpn_i) &&
                                (tlb_entries[i][8] == 1'b0) && // Mega-page bit
                                (tlb_entries[i][0] == 1'b1);   // Valid bit
                tlb_hits_m[i] = ((tlb_entries[i][`ASID] == asid_i) || (tlb_entries[i][5])) &&
                                (tlb_entries[i][`VPN1] == vpn_i[19:10]) &&
                                (tlb_entries[i][8] == 1'b1) && // Mega-page bit
                                (tlb_entries[i][0] == 1'b1); // Valid bit
        end
end

reg [IDX_SIZE-1:0] hit_idx;
reg found;

always @(*) begin: tlb_hit_index
        hit_idx = 0;
        found = 0;
        for (integer i = 0; i < NENTRIES; i = i + 1) begin
                if (tlb_hits[i]) begin
                        hit_idx = i;
                        found = 1;
                end
        end
end

reg [21:0] ppn_r;
always @(*) begin
        if (~VMEnable_i || priv_i == 2'b11) begin
                // Return vpn as ppn if virtual memory is disabled or in machine mode
                ppn_r = {2'b0, vpn_i};
        end else if (tlb_cur_state != IDLE) begin
                ppn_r = 22'b0;
        end else if (tlb_hit_k) begin
                ppn_r = tlb_entries[hit_idx][`PPN];
        end else if (tlb_hit_m) begin
                ppn_r = {tlb_entries[hit_idx][`PPN1], vpn_i[9:0]};
        end else begin
                ppn_r = 22'b0;
        end
end

assign ppn_o = ppn_r;
assign valid_o = cancel_i | (tlb_cur_state == IDLE & tlb_hit);

/*-------------------------------- PTW Outputs --------------------------------*/
assign ptw_vpn_o = vpn_i;
assign ptw_priv_o = priv_i;
assign ptw_instr_o = instr_i;
assign ptw_write_o = write_i;
assign ptw_mxr_o = mxr_i;
assign ptw_sum_o = sum_i;
assign ptw_ptppn_o = ptppn_i;

assign ptw_rden_o = (tlb_cur_state == IDLE) & rden_i & ~tlb_hit &
        vmEnable_i & (priv_i != 2'b11) & ~cancel_i;

/*-------------------------------- State Machine --------------------------------*/
localparam IDLE = 1'b0;
localparam MISS = 1'b1;

reg tlb_cur_state = IDLE;

always @(posedge clk_i) begin: tlb_state_machine
        integer i;
        if (reset_i) begin
                for (i = 0; i < NENTRIES; i = i + 1) begin
                        tlb_entries[i] <= 60'b0;
                end
                tlb_cur_state <= IDLE;
        end else begin
                if (tlb_cur_state == IDLE) begin
                        if (~rden_i | cancel_i) begin
                                // Do nothing
                        end
                        // Update LRU and tlb flags on hit
                        else if (found) begin
                                lru0 <= ~hit_idx[2];
                                if (hit_idx[2]) begin
                                        lru1[0] <= ~hit_idx[1];
                                        if (hit_idx[1]) begin
                                                lru2[0] <= ~hit_idx[0];
                                        end else begin
                                                lru2[1] <= ~hit_idx[0];
                                        end
                                end else begin
                                        lru1[1] <= ~hit_idx[1];
                                        if (hit_idx[1]) begin
                                                lru2[2] <= ~hit_idx[0];
                                        end else begin
                                                lru2[3] <= ~hit_idx[0];
                                        end
                                end
                                tlb_entries[hit_idx][6] <= 1'b1; // Set accessed bit
                                tlb_entries[hit_idx][7] <= write_i; // Set dirty bit
                        end
                        // TLB Miss
                        else begin
                                tlb_cur_state <= MISS;
                        end
                end else if (tlb_cur_state == MISS) begin
                        if (ptw_valid_i) begin
                                tlb_entries[lru_idx][`ASID] <= asid_i;
                                tlb_entries[lru_idx][`VPN] <= vpn_i;
                                tlb_entries[lru_idx][`PPN] <= ptw_ppn_i;
                                tlb_entries[lru_idx][8:0] <= ptw_flags_i;
                                tlb_cur_state <= IDLE;
                        end else if (ptw_fault_i) begin
                                // Do not update TLB on fault, just return to IDLE
                                tlb_cur_state <= IDLE;
                        end
                end else begin
                        tlb_cur_state <= IDLE;
                end
        end
end

endmodule

