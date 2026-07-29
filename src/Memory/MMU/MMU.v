/*************************************************
 *File----------MMU.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Jul 29, 2026 09:35:14 EDT
 ************************************************/

module MMU (
        input  wire        clk_i,
        input  wire        reset_i,

        // TLB Flush Signal
        input  wire        flush_i,

        // I-Cache Interface
        input  wire [31:0] i_vaddr_i,
        input  wire [31:0] i_satp_i,
        input  wire        i_rden_i,
        input  wire [1:0]  i_priv_i,
        input  wire        i_sum_i,
        input  wire        i_cancel_i,
        output wire [33:0] i_paddr_o,
        output wire        i_valid_o,

        // D-Cache Interface
        input  wire [31:0] d_vaddr_i,
        input  wire [31:0] d_satp_i,
        input  wire        d_rden_i,
        input  wire [1:0]  d_priv_i,
        input  wire        d_write_i,
        input  wire        d_mxr_i,
        input  wire        d_sum_i,
        output wire [33:0] d_paddr_o,
        output wire        d_valid_o,

        // Data Mem Interface
        output wire [31:0] DMemAddr_o,
        output wire        DMemRden_o,
        output wire [63:0] DMemWData_o,
        output wire [7:0]  DMemWren_o,
        input  wire [63:0] DMemRData_i,
        input  wire        DMemValidReady_i
);

// Convert virtual address to virtual page number
wire [19:0] i_vpn = i_vaddr_i[31:12];
wire [19:0] d_vpn = d_vaddr_i[31:12];

// Convert physical page number to physical address
wire [21:0] i_ppn;
wire [21:0] d_ppn;
assign i_paddr_o = {i_ppn, i_vaddr_i[11:0]};
assign d_paddr_o = {d_ppn, d_vaddr_i[11:0]};

// i-tlb - ptw interface
wire [19:0]  iptw_vpn;
wire         iptw_rden;
wire [1:0]   iptw_priv;
wire         iptw_instr;
wire         iptw_write;
wire         iptw_mxr;
wire         iptw_sum;
wire [21:0]  iptw_ptppn;
wire [21:0]  iptw_ppn;
wire [8:0]   iptw_flags;
wire         iptw_valid;
wire         iptw_fault;

// d-tlb - ptw interface
wire [19:0]  dptw_vpn;
wire         dptw_rden;
wire [1:0]   dptw_priv;
wire         dptw_instr;
wire         dptw_write;
wire         dptw_mxr;
wire         dptw_sum;
wire [21:0]  dptw_ptppn;
wire [21:0]  dptw_ppn;
wire [8:0]   dptw_flags;
wire         dptw_valid;
wire         dptw_fault;

TLB itlb(
        .clk_i(clk_i),
        .reset_i(reset_i),

        .vpn_i(i_vpn),
        .satp_i(i_satp_i),
        .rden_i(i_rden_i),
        .flush_i(flush_i),
        .priv_i(i_priv_i),
        .instr_i(1'b1), // Always instruction fetch for i-tlb
        .write_i(1'b0), // i-cache never writes to memory
        .mxr_i(1'b0),   // i-cache doesn't care about MXR
        .sum_i(i_sum_i),
        .cancel_i(i_cancel_i),
        .ppn_o(i_ppn),
        .valid_o(i_valid_o),

        .ptw_vpn_o(iptw_vpn),
        .ptw_rden_o(iptw_rden),
        .ptw_priv_o(iptw_priv),
        .ptw_instr_o(iptw_instr),
        .ptw_write_o(iptw_write),
        .ptw_mxr_o(iptw_mxr),
        .ptw_sum_o(iptw_sum),
        .ptw_ptppn_o(iptw_ptppn),
        .ptw_ppn_i(iptw_ppn),
        .ptw_flags_i(iptw_flags),
        .ptw_valid_i(iptw_valid),
        .ptw_fault_i(iptw_fault)
);

TLB dtlb(
        .clk_i(clk_i),
        .reset_i(reset_i),

        .vpn_i(d_vpn),
        .satp_i(d_satp_i),
        .rden_i(d_rden_i),
        .flush_i(flush_i),
        .priv_i(d_priv_i),
        .instr_i(1'b0), // Always data access for d-tlb
        .write_i(d_write_i),
        .mxr_i(d_mxr_i),
        .sum_i(d_sum_i),
        .cancel_i(1'b0), // d-cache never cancels
        .ppn_o(d_ppn),
        .valid_o(d_valid_o),

        .ptw_vpn_o(dptw_vpn),
        .ptw_rden_o(dptw_rden),
        .ptw_priv_o(dptw_priv),
        .ptw_instr_o(dptw_instr),
        .ptw_write_o(dptw_write),
        .ptw_mxr_o(dptw_mxr),
        .ptw_sum_o(dptw_sum),
        .ptw_ptppn_o(dptw_ptppn),
        .ptw_ppn_i(dptw_ppn),
        .ptw_flags_i(dptw_flags),
        .ptw_valid_i(dptw_valid),
        .ptw_fault_i(dptw_fault)
);

PTW ptw(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .i_vpn_i(iptw_vpn),
        .i_rden_i(iptw_rden),
        .i_priv_i(iptw_priv),
        .i_instr_i(iptw_instr),
        .i_write_i(iptw_write),
        .i_mxr_i(iptw_mxr),
        .i_sum_i(iptw_sum),
        .i_ptppn_i(iptw_ptppn),
        .i_ppn_o(iptw_ppn),
        .i_flags_o(iptw_flags),
        .i_valid_o(iptw_valid),
        .i_fault_o(iptw_fault),
        .d_vpn_i(dptw_vpn),
        .d_rden_i(dptw_rden),
        .d_priv_i(dptw_priv),
        .d_instr_i(dptw_instr),
        .d_write_i(dptw_write),
        .d_mxr_i(dptw_mxr),
        .d_sum_i(dptw_sum),
        .d_ptppn_i(dptw_ptppn),
        .d_ppn_o(dptw_ppn),
        .d_flags_o(dptw_flags),
        .d_valid_o(dptw_valid),
        .d_fault_o(dptw_fault),
        .DMemAddr_o(DMemAddr_o),
        .DMemRden_o(DMemRden_o),
        .DMemWData_o(DMemWData_o),
        .DMemWren_o(DMemWren_o),
        .DMemRData_i(DMemRData_i),
        .DMemValidReady_i(DMemValidReady_i)
);

endmodule

