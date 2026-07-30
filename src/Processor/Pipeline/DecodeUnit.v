/*************************************************
 *File----------DecodeUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 15:52:48 UTC
 ************************************************/

module DecodeUnit #(
        parameter BP_ADDR_BITS = 12,
        parameter BHT_SIZE = 1 << BP_ADDR_BITS,
        parameter BH_BITS = 9
)(
        input  wire        clk_i,
        input  wire        reset_i,
        // Pipeline Control Signals
        input  wire        D_stall_i,
        input  wire        D_flush_i,
        input  wire        E_flush_i,
        input  wire        E_stall_i,
        input  wire        M_busy_i,
        input  wire        E_takeBranch_i,
        input  wire [31:0] EM_PC_i,
        output wire        D_satpWrite_o,
        output wire        D_predictPC_o,
        output wire [31:0] D_PCprediction_o,
        output wire        dataHazard_o,
        output wire        D_isPrivileged_o,
        output wire [1:0]  D_privilege_o,
        output wire        D_data_fault_o,
        // CSR Interface
        output wire [11:0] csrRAddr_o,
        input  wire [31:0] csrRData_i,
        input  wire [63:0] csrMStatus_i,
        input  wire [63:0] csrMedeleg_i,
        input  wire [31:0] csrMideleg_i,
        input  wire [31:0] csrMie_i,
        input  wire [31:0] csrMtvec_i,
        input  wire [31:0] csrMepc_i,
        input  wire [31:0] csrMCause_i,
        input  wire [31:0] csrMip_i,
        input  wire [31:0] csrStvec_i,
        input  wire [31:0] csrSepc_i,
        input  wire [31:0] csrSCause_i,
        output wire [6:0]  csrMStatusSet_o, // {MPP[1:0], MPIE, MIE, SPP, SPIE, SIE}
        output wire [31:0] csrMepcSet_o,
        output wire [31:0] csrMCauseSet_o,
        output wire [31:0] csrSepcSet_o,
        output wire [31:0] csrSCauseSet_o,
        output wire        csrTrapSetEn_o,
        // MMU Fault exception signals
        input  wire [2:0]  page_fault_i,
        // Fetch Unit Interface
        input  wire [31:0] FD_PC_i,
        input  wire [31:0] FD_instr_i,
        input  wire        FD_isRV32C_i,
        input  wire        FD_nop_i,
        // Execute Unit Interface
        output reg  [31:0] DE_PC_o,
        output reg  [31:0] DE_instr_o,
        output reg         DE_isRV32C_o,
        output reg         DE_nop_o,
        output reg  [1:0]  DE_priv_o,
        output reg         DE_isLUI_o,
        output reg         DE_isAUIPC_o,
        output reg         DE_isJAL_o,
        output reg         DE_isJALR_o,
        output reg         DE_isBranch_o,
        output reg         DE_isLoad_o,
        output reg         DE_isStore_o,
        output reg         DE_isALUI_o,
        output reg         DE_isALUR_o,
        output reg         DE_isFENCE_o,
        output reg         DE_isSYS_o,
        output reg         DE_isSFENCEVMA_o,
        output reg         DE_isEBREAK_o,
        output reg         DE_isCSR_o,
        output reg         DE_isAMO_o,
        output reg         DE_isFPU_o,
        output reg  [5:0]  DE_rdId_o,
        output reg  [5:0]  DE_rs1Id_o,
        output reg  [5:0]  DE_rs2Id_o,
        output reg  [5:0]  DE_rs3Id_o,
        output reg  [11:0] DE_csrId_o,
        output reg  [31:0] DE_csrData_o,
        output reg  [2:0]  DE_funct3_o,
        output reg  [7:0]  DE_funct3_is_o,
        output reg  [6:0]  DE_funct7_o,
        output reg  [31:0] DE_Iimm_o,
        output reg  [31:0] DE_Simm_o,
        output reg  [31:0] DE_Bimm_o,
        output reg  [31:0] DE_Uimm_o,
        output reg         DE_isRV32M_o,
        output reg         DE_isMUL_o,
        output reg         DE_isDIV_o,
        output reg         DE_wbEnable_o,
        output reg         DE_predictBranch_o,
        output reg  [BP_ADDR_BITS-1:0] DE_bhtIndex_o,
        output reg  [31:0] DE_predictRA_o
);

// NOP - ADDI x0, x0, 0
localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

/*
 * Used RISC-V ISM Volume I: Version 20250508, Ch. 35, Page 609
 * The RISC-V (RV32G) opcodes inst[6:2] (inst[1:0]=11)
 * | inst[6:5] |   000  |   001  |   010  |   011  |   100  |   101  |
 * +-----------+--------+--------+--------+--------+--------+--------+
 * |        00 | LOAD   | FLOAD  |        | FENCE  | ALUImm | AUIPC  |
 * |        01 | STORE  | FSTORE |        | AMO    | ALUreg | LUI    |
 * |        10 | FMADD  | FMSUB  | FNMSUB | FNMADD | FPU    |        |
 * |        11 | BRANCH | JALR   |        | JAL    | SYSTEM |        |
 * +-----------+--------+--------+--------+--------+--------+--------+
 *
 * ALUreg  // rd <- rs1 OP rs2
 * ALUimm  // rd <- rs1 OP Iimm
 * Branch  // if(rs1 OP rs2) PC<-PC+Bimm
 * JALR    // rd <- PC+4; PC<-rs1+Iimm
 * JAL     // rd <- PC+4; PC<-PC+Jimm
 * AUIPC   // rd <- PC + Uimm
 * LUI     // rd <- Uimm
 * Load    // rd <- mem[rs1+Iimm]
 * Store   // mem[rs1+Simm] <- rs2
 * Fence   // special
 * SYSTEM  // special
 */

/*------------Instruction Allignment and Decompression-----------*/
wire [31:0] D_rawInstr = FD_nop_i ? NOP : FD_instr_i;
// wire [31:0] D_rawInstr = FD_instr_i;
wire [31:0] D_instr; // = FD_instr_i; // = FD_nop_i ? NOP : FD_instr_i;
// wire        D_isRV32C = ~&D_rawInstr[1:0];
Decompressor decomp(.compressed_i(D_rawInstr), .decompressed_o(D_instr));

/*--------------INSTRUCTION DECODING--------------*/
// 11 RV32I OpCodes
// bits [1:0] are always 11 for all opcodes
reg D_isLUI;
reg D_isAUIPC;
reg D_isJAL;
reg D_isJALR;
reg D_isBranch;
reg D_isLoad;
reg D_isStore;
reg D_isALUI;
reg D_isALUR;
reg D_isFENCE;
reg D_isSYS;
reg D_isAMO;
reg D_isFPU;

// Handle Unimplemented instructions
reg D_isUNIMP;

always @(*) begin
        D_isLUI   = 1'b0;
        D_isAUIPC = 1'b0;
        D_isJAL   = 1'b0;
        D_isJALR  = 1'b0;
        D_isBranch= 1'b0;
        D_isLoad  = 1'b0;
        D_isStore = 1'b0;
        D_isALUI  = 1'b0;
        D_isALUR  = 1'b0;
        D_isFENCE = 1'b0;
        D_isSYS   = 1'b0;
        D_isAMO   = 1'b0;
        D_isFPU   = 1'b0;
        D_isUNIMP = 1'b0;

        casez (D_instr[6:0])
                7'b0110111: D_isLUI    = 1'b1;
                7'b0010111: D_isAUIPC  = 1'b1;
                7'b1101111: D_isJAL    = 1'b1;
                7'b1100111: D_isJALR   = 1'b1;
                7'b1100011: D_isBranch = 1'b1;
                7'b0000?11: D_isLoad   = 1'b1;  // instr[2]: FLW
                7'b0100?11: D_isStore  = 1'b1;  // instr[2]: FSW
                7'b0010011: D_isALUI   = 1'b1;
                7'b0110011: D_isALUR   = 1'b1;
                7'b0001111: D_isFENCE  = 1'b1;
                7'b1110011: D_isSYS    = 1'b1;
                7'b0101111: D_isAMO    = 1'b1;
                7'b10???11: D_isFPU    = 1'b1;
                default:    D_isUNIMP  = 1'b1;
        endcase
end

// Instruction Functions
wire [2:0] D_funct3 = D_instr[14:12];
wire [6:0] D_funct7 = D_instr[31:25];

// Source and dest registers
wire [4:0] D_raw_rdId  = D_instr[11:7];
wire [4:0] D_raw_rs1Id = D_instr[19:15];
wire [4:0] D_raw_rs2Id = D_instr[24:20];
wire [4:0] D_raw_rs3Id = D_instr[31:27]; // For FMA ops

// Immediate Values
wire [31:0] D_Iimm =
        {{21{D_instr[31]}}, D_instr[30:20]};
wire [31:0] D_Simm =
        {{21{D_instr[31]}}, D_instr[30:25],D_instr[11:7]};
wire [31:0] D_Bimm =
        {{20{D_instr[31]}}, D_instr[7],D_instr[30:25],D_instr[11:8],1'b0};
wire [31:0] D_Uimm =
        {D_instr[31], D_instr[30:12], {12{1'b0}}};
wire [31:0] D_Jimm =
        {{12{D_instr[31]}}, D_instr[19:12],D_instr[20],D_instr[30:21],1'b0};

// Privileged Instructions
wire D_isPrv       = D_isSYS & (D_funct3 == 3'b000);
wire D_isECALL     = D_isPrv & (D_instr[22:20] == 3'b000) & ~D_instr[25];
wire D_isEBREAK    = D_isPrv & (D_instr[22:20] == 3'b001) & ~D_instr[25];
wire D_isMRET      = D_isPrv &  D_instr[21] & (D_instr[30:28] == 3'b011) & ~D_instr[25];
wire D_isSRET      = D_isPrv &  D_instr[21] & (D_instr[30:28] == 3'b001) & ~D_instr[25];
wire D_isWFI       = D_isPrv & (D_instr[22:20] == 3'b101) & ~D_instr[25];
wire D_isSFENCEVMA = D_isPrv & ~D_instr[21] & (D_instr[30:28] == 3'b001) &  D_instr[25];

wire D_isCSR = D_isSYS & (D_funct3[1:0] != 2'b00);
wire [11:0] D_csrId = D_instr[31:20];

wire D_isLR  = D_isAMO & (D_funct7[6:2] == 5'b00010);

wire D_isLoadOrAMO  = D_isLoad  | D_isAMO;
wire D_isStoreOrAMO = D_isStore | (D_isAMO & ~D_isLR);

wire D_readsRs1 = !(D_isJAL || D_isLUI || D_isAUIPC);

wire D_readsRs2 = (D_isStoreOrAMO || D_isBranch || D_isALUR || D_isFPU);

wire D_isRV32M = D_isALUR  & D_instr[25];
wire D_isMUL   = D_isRV32M & !D_instr[14];
wire D_isDIV   = D_isRV32M &  D_instr[14];

// rd is a FP reg if op is FLW, FMA, R-Type FPU, FCVT.S.W(U), or FMV.W.X
wire D_rdIsFP = (D_instr[6:2] == 5'b00001)  || // FLW
        (D_instr[6:4] == 3'b100)            || // FMA F(N)MADD / F(N)MSUB
        (D_isFPU && ((D_instr[31] == 1'b0)  || // R-Type FPU Instr
        (D_instr[31:28] == 4'b1101)         || // FCVT.S.W(U)
        (D_instr[31:28] == 4'b1111)));         // FMV.W.X

// rs1 is a FP reg if op is FPU except for FCVT.S.W(U) and FMV.W.X
wire D_rs1IsFP = D_isFPU &&
        !((D_instr[4:2]   == 3'b100) && (
          (D_instr[31:28] == 4'b1101) ||     // FCVT.S.W(U)
          (D_instr[31:28] == 4'b1111)));      // FMV.W.X

// rs2 is a FP reg if op is FPU or FSW
wire D_rs2IsFP = D_isFPU || (D_isStore && D_instr[2]);

// Floating Point Registers are encoded with id[5] == 1
wire [5:0] D_rdId =  {D_rdIsFP , D_raw_rdId };
wire [5:0] D_rs1Id = {D_rs1IsFP, D_raw_rs1Id};
wire [5:0] D_rs2Id = {D_rs2IsFP, D_raw_rs2Id};
wire [5:0] D_rs3Id = {1'b1     , D_raw_rs3Id};

/*----------------BRANCH PREDICTION---------------*/
reg [1:0] BHT[BHT_SIZE-1:0]; // Branch History Table

reg [BH_BITS-1:0] branchHist = 0;

integer i;
always @(posedge clk_i) begin
        if (reset_i) begin
                for (i = 0; i < BHT_SIZE; i = i+1)
                        BHT[i] <= 0;
                branchHist <= 0;
        end else if (!E_stall_i && DE_isBranch_o) begin
                branchHist <= {E_takeBranch_i, branchHist[BH_BITS-1:1]};
                BHT[DE_bhtIndex_o] <=
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b000 ? 2'b00 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b001 ? 2'b00 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b010 ? 2'b01 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b011 ? 2'b10 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b100 ? 2'b01 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b101 ? 2'b10 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b110 ? 2'b11 :
                        2'b11 ;
        end
end

localparam BH_SHAMT = BP_ADDR_BITS - BH_BITS;
wire [BP_ADDR_BITS-1:0] D_bhtIndex = FD_PC_i[BP_ADDR_BITS:1] ^ {branchHist, {BH_SHAMT{1'b0}}};

wire D_predictBranch = BHT[D_bhtIndex][1];

/*--------------RETURN ADDRESS STACK--------------*/
reg [31:0] RAS_0;
reg [31:0] RAS_1;
reg [31:0] RAS_2;
reg [31:0] RAS_3;

wire [31:0] D_nextPC = FD_PC_i + (FD_isRV32C_i ? 2 : 4);

always @(posedge clk_i) begin
        if (!D_stall_i && !FD_nop_i && !D_flush_i) begin
                if ((D_isJAL || D_isJALR) && D_rdId == 1) begin
                        RAS_3 <= RAS_2;
                        RAS_2 <= RAS_1;
                        RAS_1 <= RAS_0;
                        RAS_0 <= D_nextPC;
                end
                if(D_isJALR && D_rdId==0 && (D_rs1Id==1 || D_rs1Id==5)) begin
                        RAS_0 <= RAS_1;
                        RAS_1 <= RAS_2;
                        RAS_2 <= RAS_3;
                end
        end
end

/*------------------Illegal Instruction Check-----------------*/
wire       D_csrRO   = D_csrId[11] & D_csrId[10]; // CSR is read only if csrId[11:10] == 11
wire [1:0] D_csrPriv = D_csrId[9:8];              // Lowest priv allowed
wire       D_isCSRWrite = D_isCSR & |D_rs1Id;     // Is rs1 is not 0, then is CSR Write

wire D_isIllegalCSR = (D_isCSR & ((D_csrRO & D_isCSRWrite) | (D_csrPriv > DD_privilege)));
wire D_isIllegal = (D_isUNIMP | D_isIllegalCSR);

/*------------------CSR Read-----------------*/
assign csrRAddr_o = D_isCSR ? D_csrId : {12{1'bZ}};

// Writing to CSR 0x180 (satp) needs to stall the fetch unit so it can use the updted satp csr
assign D_satpWrite_o = D_isCSRWrite & (D_csrId == 12'h180);

/*------------------Trap Handlers-----------------*/
localparam US = 2'b00, SU = 2'b01, MA = 2'b11;

// Privilage is machine on startup
reg [1:0] DD_privilege = MA;
assign D_privilege_o = DD_privilege;

// Interupts
wire D_isMTIP = csrMip_i[7] & csrMie_i[7];
wire D_isSTIP = csrMip_i[5] & csrMie_i[5];
wire D_isMInterupt = (csrMStatus_i[3] | csrMStatus_i[1]) & D_isMTIP;
wire D_isSInterupt = csrMStatus_i[1] & D_isSTIP;
wire D_isInterupt  = ~FD_nop_i & (D_isMInterupt | D_isSInterupt);

// Exceptions
wire D_isException = D_isECALL | D_isIllegal | |page_fault_i;
assign D_data_fault_o = |page_fault_i[2:1];

wire D_isTrap = D_isInterupt | D_isException;
wire D_isPrivileged = D_isTrap | D_isMRET | D_isSRET;

// Set PC, CSRs, and privilege level for traps
reg [31:0] D_trapCause;
always @(*) begin
        if (D_isInterupt) begin
                if (D_isMTIP)
                        D_trapCause = 32'h8007;
                else // if (D_isSTIP)
                        D_trapCause = 32'h8005;
        end else if (D_isException) begin
                if (D_isECALL) begin
                        if (DD_privilege == US)
                                D_trapCause = 32'd8;
                        else if (DD_privilege == SU)
                                D_trapCause = 32'd9;
                        else
                                D_trapCause = 32'd11;
                end else if (D_isIllegal) begin
                        D_trapCause = 32'd2;
                end else if (|page_fault_i) begin
                        if (page_fault_i[2])
                                D_trapCause = 32'd15; // Store/AMO Page Fault
                        else if (page_fault_i[1])
                                D_trapCause = 32'd13; // Load Page Fault
                        else // if (page_fault_i[0])
                                D_trapCause = 32'd12; // Instruction Page Fault
                end else
                        D_trapCause = 32'd19; // Default to hardware error
        end else begin
                D_trapCause = 32'd19; // Default to hardware error
        end
end

wire [1:0] D_trapPrivilege = D_isInterupt ?
        (csrMideleg_i[D_trapCause[4:0]] ? SU : MA) :
        (csrMedeleg_i[D_trapCause[5:0]] ? SU : MA);

wire [31:0] D_MRetJumpAddr = csrMepc_i;
wire [31:0] D_SRetJumpAddr = csrSepc_i;
wire [31:0] D_trapJumpAddr = (D_trapPrivilege == SU) ? csrStvec_i : csrMtvec_i;

wire [1:0]  D_privilegeSet =
         D_isInterupt ? ((D_isSInterupt) ? SU : MA) :
        (D_isTrap     ? ((D_trapPrivilege == SU) ? SU : MA) :
        (D_isMRET     ? csrMStatus_i[12:11] :
        (D_isSRET     ? {1'b0, csrMStatus_i[8]} : DD_privilege)));

wire D_isMTrap = D_isTrap && D_trapPrivilege == MA;
wire D_isSTrap = D_isTrap && D_trapPrivilege == SU;

wire [1:0] D_mppSet    = D_isMTrap ? DD_privilege    : csrMStatus_i[12:11];
wire       D_sppSet    = D_isSTrap ? DD_privilege[0] : csrMStatus_i[8];

wire       D_mpieSet   = D_isMTrap ? csrMStatus_i[3] : (D_isMRET  ? 1'b1 : csrMStatus_i[7]);
wire       D_mieSet    = D_isMTrap ? 1'b0 : (D_isMRET  ? csrMStatus_i[7] : csrMStatus_i[3]);
wire       D_spieSet   = D_isTrap  ? csrMStatus_i[1] : (D_isSRET  ? 1'b1 : csrMStatus_i[5]);
wire       D_sieSet    = D_isTrap  ? 1'b0 : (D_isSRET  ? csrMStatus_i[5] : csrMStatus_i[1]);

assign csrMStatusSet_o = {D_mppSet, D_mpieSet, D_mieSet, D_sppSet, D_spieSet, D_sieSet};

assign csrMepcSet_o    = D_isMTrap ?
        (D_isInterupt ? FD_PC_i :
        (D_data_fault_o ? EM_PC_i : FD_PC_i)) : csrMepc_i;
assign csrMCauseSet_o  = D_isMTrap ? D_trapCause : csrMCause_i;
assign csrSepcSet_o    = D_isSTrap ?
        (D_isInterupt ? FD_PC_i :
        (D_data_fault_o ? EM_PC_i : FD_PC_i)) : csrSepc_i;
assign csrSCauseSet_o  = D_isSTrap ? D_trapCause : csrSCause_i;
assign csrTrapSetEn_o  = D_stall_i ? 1'b0 : D_isPrivileged;

always @(posedge clk_i) begin
        if (reset_i) begin
                DD_privilege <= 2'b11;
        end
        else if (!D_stall_i) begin
                DD_privilege <= D_privilegeSet;
        end
end

/*------------Branch Prediction Result------------*/
assign D_predictPC_o = (!FD_nop_i & // !D_isUNIMP &&
        (D_isJAL | D_isJALR | D_isMRET | D_isSRET |
        (D_isBranch & D_predictBranch))) | D_isTrap;

assign D_PCprediction_o =
        D_isTrap  ? D_trapJumpAddr  :
        D_isMRET  ? D_MRetJumpAddr  :
        D_isSRET  ? D_SRetJumpAddr  :
        D_isJALR  ? RAS_0           :
        (FD_PC_i + (D_isJAL ? D_Jimm : D_Bimm));


/*------------------------------------------------*/
wire rs1Hazard = D_readsRs1 && (D_rs1Id == DE_rdId_o);
wire rs2Hazard = D_readsRs2 && (D_rs2Id == DE_rdId_o);

assign dataHazard_o = ~FD_nop_i &
        ((DE_isLoad_o | DE_isAMO_o | DE_isCSR_o) & (rs1Hazard | rs2Hazard)) |
        (D_isLoadOrAMO & (DE_isStore_o | DE_isAMO_o | DE_isFENCE_o | DE_isSFENCEVMA_o)) |
        ((D_isCSR | D_isPrivileged) & (DE_isCSR_o & (DE_rs1Id_o != 6'b0)));
assign D_isPrivileged_o = D_isPrivileged;

wire D_isNOP = E_flush_i | FD_nop_i | D_isWFI;
always @(posedge clk_i) begin
        if (!D_stall_i) begin
                DE_PC_o <= FD_PC_i;
                DE_instr_o <= D_isNOP ? NOP : D_instr;
                DE_isRV32C_o <= FD_isRV32C_i;
                DE_nop_o <= D_isNOP;
                DE_priv_o <= DD_privilege;

                DE_isLUI_o        <= D_isLUI;
                DE_isAUIPC_o      <= D_isAUIPC;
                DE_isJAL_o        <= D_isJAL;
                DE_isJALR_o       <= D_isJALR;
                DE_isBranch_o     <= D_isBranch;
                DE_isLoad_o       <= D_isLoad;
                DE_isStore_o      <= D_isStore;
                DE_isALUI_o       <= D_isALUI;
                DE_isALUR_o       <= D_isALUR;
                DE_isFENCE_o      <= D_isFENCE;
                DE_isSYS_o        <= D_isSYS;
                DE_isSFENCEVMA_o  <= D_isSFENCEVMA;
                DE_isEBREAK_o     <= D_isEBREAK;
                DE_isCSR_o        <= D_isCSR;
                DE_isAMO_o        <= D_isAMO;
                DE_isFPU_o        <= D_isFPU;

                DE_rdId_o    <= D_rdId;
                DE_rs1Id_o   <= D_rs1Id;
                DE_rs2Id_o   <= D_rs2Id;
                DE_rs3Id_o   <= D_rs3Id;
                DE_csrId_o   <= D_csrId;
                DE_csrData_o <= csrRData_i;

                DE_funct3_o <= D_funct3;
                DE_funct3_is_o <= 8'b00000001 << D_instr[14:12];
                DE_funct7_o <= D_funct7;

                DE_Iimm_o <= D_Iimm;
                DE_Simm_o <= D_Simm;
                DE_Bimm_o <= D_Bimm;
                DE_Uimm_o <= D_Uimm;

                DE_isRV32M_o <= D_isRV32M;
                DE_isMUL_o   <= D_isMUL;
                DE_isDIV_o   <= D_isDIV;

                DE_wbEnable_o <= ~(D_isBranch | D_isStore);

                DE_predictBranch_o <= D_predictBranch;
                DE_bhtIndex_o <= D_bhtIndex;
                DE_predictRA_o <= RAS_0;
        end

        if (reset_i || ((E_flush_i || FD_nop_i || D_isInterupt) && !M_busy_i)) begin
                DE_instr_o        <= NOP;
                DE_nop_o          <= 1'b1;
                DE_isLUI_o        <= 1'b0;
                DE_isAUIPC_o      <= 1'b0;
                DE_isJAL_o        <= 1'b0;
                DE_isJALR_o       <= 1'b0;
                DE_isBranch_o     <= 1'b0;
                DE_isLoad_o       <= 1'b0;
                DE_isStore_o      <= 1'b0;
                DE_isALUI_o       <= 1'b0;
                DE_isALUR_o       <= 1'b0;
                DE_isFENCE_o      <= 1'b0;
                DE_isSYS_o        <= 1'b0;
                DE_isSFENCEVMA_o  <= 1'b0;
                DE_isEBREAK_o     <= 1'b0;
                DE_isCSR_o        <= 1'b0;
                DE_isAMO_o        <= 1'b0;
                DE_isFPU_o        <= 1'b0;
                DE_isRV32M_o      <= 1'b0;
                DE_isMUL_o        <= 1'b0;
                DE_isDIV_o        <= 1'b0;
                DE_wbEnable_o     <= 1'b0;
        end
end

initial begin
        for (i = 0; i < BHT_SIZE; i = i+1)
                BHT[i] = 0;
        DE_instr_o        = NOP;
        DE_nop_o          = 1'b1;
        DE_isLUI_o        = 1'b0;
        DE_isAUIPC_o      = 1'b0;
        DE_isJAL_o        = 1'b0;
        DE_isJALR_o       = 1'b0;
        DE_isBranch_o     = 1'b0;
        DE_isLoad_o       = 1'b0;
        DE_isStore_o      = 1'b0;
        DE_isALUI_o       = 1'b0;
        DE_isALUR_o       = 1'b0;
        DE_isFENCE_o      = 1'b0;
        DE_isSYS_o        = 1'b0;
        DE_isSFENCEVMA_o  = 1'b0;
        DE_isEBREAK_o     = 1'b0;
        DE_isCSR_o        = 1'b0;
        DE_isAMO_o        = 1'b0;
        DE_isFPU_o        = 1'b0;
        DE_isRV32M_o      = 1'b0;
        DE_isMUL_o        = 1'b0;
        DE_isDIV_o        = 1'b0;
        DE_wbEnable_o     = 1'b0;
end

endmodule

