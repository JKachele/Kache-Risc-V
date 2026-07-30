/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/

module Processor(
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire [31:0] rvec_i,
        // Interupts
        input  wire        timerIRQ_i,
        input  wire [63:0] csrTime_i,
        input  wire [2:0]  page_fault_i,
        // Memory
        output wire        tlb_flush_o,
        output wire        IC_strb_o,
        output wire        IC_cancel_o,
        output wire [31:0] IC_addr_o,
        output wire [31:0] IC_satp_o,
        output wire [1:0]  IC_priv_o,
        output wire        IC_sum_o,
        input  wire [31:0] IC_data_i,
        input  wire        IC_valid_i,
        input  wire        IC_cmp_i,

        output wire [31:0] DC_addr_o,
        output wire        DC_flush_o,
        output wire        DC_rStrb_o,
        output wire [63:0] DC_wData_o,
        output wire [7:0]  DC_wMask_o,
        output wire [31:0] DC_satp_o,
        output wire [1:0]  DC_priv_o,
        output wire        DC_mxr_o,
        output wire        DC_sum_o,
        input  wire [63:0] DC_rData_i,
        input  wire        DC_validReady_i
);

wire [31:0] DC_rAddr;
wire [31:0] DC_rSatp;
wire [1:0]  DC_rPriv;
wire        DC_rMxr;
wire        DC_rSum;
wire [31:0] DC_wAddr;
wire [31:0] DC_wSatp;
wire [1:0]  DC_wPriv;
wire        DC_wMxr;
wire        DC_wSum;
assign DC_addr_o = DC_rStrb_o ? DC_rAddr : DC_wAddr;
assign DC_satp_o = DC_rStrb_o ? DC_rSatp : DC_wSatp;
assign DC_priv_o = DC_rStrb_o ? DC_rPriv : DC_wPriv;
assign DC_mxr_o = DC_rStrb_o ? DC_rMxr : DC_wMxr;
assign DC_sum_o = DC_rStrb_o ? DC_rSum : DC_wSum;

/******************************************************************************
 ----------------------------------Registers-----------------------------------
 ******************************************************************************/
wire [63:0] rs1Data;
wire [63:0] rs2Data;
wire [63:0] rs3Data;
wire [5:0]  rdId;
wire [63:0] rdData;
wire [5:0]  rs1Id;
wire [5:0]  rs2Id;
wire [5:0]  rs3Id;

// CSR
wire [11:0] csrWAddr;
wire [31:0] csrWData;
wire        csrWEnable;
wire [11:0] csrRAddr;
wire [31:0] csrRData;
wire        csrInstStep;
wire [4:0]  csrFFlagsSet;
wire [2:0]  csrFRM;
wire [63:0] csrMStatus;
wire [63:0] csrMedeleg;
wire [31:0] csrMideleg;
wire [31:0] csrMie;
wire [31:0] csrMtvec;
wire [31:0] csrMepc;
wire [31:0] csrMCause;
wire [31:0] csrMip;
wire [31:0] csrStvec;
wire [31:0] csrSepc;
wire [31:0] csrSCause;
wire [31:0] csrSatp;
wire [6:0]  csrMStatusSet; // {MPP[1:0], MPIE, MIE, SPP, SPIE, SIE}
wire [31:0] csrMepcSet;
wire [31:0] csrMCauseSet;
wire [31:0] csrSepcSet;
wire [31:0] csrSCauseSet;
wire        csrTrapSetEn;

RegisterFile registers(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rdId_i(rdId),
        .rdData_i(rdData),
        .rs1Id_i(rs1Id),
        .rs2Id_i(rs2Id),
        .rs3Id_i(rs3Id),
        .rs1Data_o(rs1Data),
        .rs2Data_o(rs2Data),
        .rs3Data_o(rs3Data)
);

CSR_RegFile csr(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .mtimeIRQ_i(timerIRQ_i),
        .csrWAddr_i(csrWAddr),
        .csrWEnable_i(csrWEnable),
        .csrWData_i(csrWData),
        .csrRAddr_i(csrRAddr),
        .csrRData_o(csrRData),
        .csrInstStep_i(csrInstStep),
        .csrTime_i(csrTime_i),
        .csrFFlagsSet_i(csrFFlagsSet),
        .csrFRM_o(csrFRM),
        .csrMStatus_o(csrMStatus),
        .csrMedeleg_o(csrMedeleg),
        .csrMideleg_o(csrMideleg),
        .csrMie_o(csrMie),
        .csrMtvec_o(csrMtvec),
        .csrMepc_o(csrMepc),
        .csrMCause_o(csrMCause),
        .csrMip_o(csrMip),
        .csrStvec_o(csrStvec),
        .csrSepc_o(csrSepc),
        .csrSCause_o(csrSCause),
        .csrSatp_o(csrSatp),
        .csrMStatusSet_i(csrMStatusSet),
        .csrMepcSet_i(csrMepcSet),
        .csrMCauseSet_i(csrMCauseSet),
        .csrSepcSet_i(csrSepcSet),
        .csrSCauseSet_i(csrSCauseSet),
        .csrTrapSetEn_i(csrTrapSetEn)
);

/******************************************************************************
 -------------------------------CONTROL SIGNALS--------------------------------
 ******************************************************************************/
/*verilator public_flat_rw_on*/
wire HALT;
wire F_stall;
wire D_stall;
wire E_stall;
wire D_flush;
wire E_flush;
wire M_flush;
wire F_busy;
wire dataHazard;
wire D_isPrivileged;
wire D_data_fault;
wire D_predictPC;
wire [31:0] D_PCprediction;
wire D_satpWrite;
wire E_satpWrite;
wire [31:0] E_satpUpdate;
/*verilator public_off*/

ControlUnit control(
        .HALT_i(HALT),
        .F_busy_i(F_busy),
        .dataHazard_i(dataHazard),
        .D_isPrivileged_i(D_isPrivileged),
        .D_data_fault_i(D_data_fault),
        .EM_isCSRWrite_i(EM_isCSRWrite),
        .aluBusy_i(aluBusy),
        .M_busy_i(M_busy),
        .E_correctPC_i(E_correctPC),
        .F_stall_o(F_stall),
        .D_stall_o(D_stall),
        .E_stall_o(E_stall),
        .D_flush_o(D_flush),
        .E_flush_o(E_flush),
        .M_flush_o(M_flush)
);

/******************************************************************************
 ----------------------------------FETCH UNIT----------------------------------
 ******************************************************************************/
wire [31:0] FD_PC;
wire [31:0] FD_instr;
wire        FD_isRV32C;
wire        FD_nop;
wire [1:0]  D_privilege;
FetchUnit fetch(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rvec_i(rvec_i),
        .F_busy_o(F_busy),
        .F_stall_i(F_stall),
        .D_flush_i(D_flush),
        .D_predictPC_i(D_predictPC),
        .D_PCprediction_i(D_PCprediction),
        .E_correctPC_i(E_correctPC),
        .E_PCcorrection_i(E_PCcorrection),
        .D_privilege_i(D_privilege),
        .D_satpWrite_i(D_satpWrite),
        .E_satpWrite_i(E_satpWrite),
        .E_satpUpdate_i(E_satpUpdate),
        .csrSatp_i(csrSatp),
        .csrMStatus_i(csrMStatus),
        .IC_Strb_o(IC_strb_o),
        .IC_Cancel_o(IC_cancel_o),
        .IC_Addr_o(IC_addr_o),
        .IC_satp_o(IC_satp_o),
        .IC_priv_o(IC_priv_o),
        .IC_sum_o(IC_sum_o),
        .IC_Data_i(IC_data_i),
        .IC_Valid_i(IC_valid_i),
        .IC_Cmp_i(IC_cmp_i),
        .FD_PC_o(FD_PC),
        .FD_instr_o(FD_instr),
        .FD_isRV32C_o(FD_isRV32C),
        .FD_nop_o(FD_nop)
);
/******************************************************************************
 ---------------------------------DECODE UNIT----------------------------------
 ******************************************************************************/
wire [31:0] DE_PC;
wire [31:0] DE_instr;
wire        DE_isRV32C;
wire        DE_nop;
wire [1:0]  DE_priv;

wire        DE_isLUI;
wire        DE_isAUIPC;
wire        DE_isJAL;
wire        DE_isJALR;
wire        DE_isBranch;
wire        DE_isLoad;
wire        DE_isStore;
wire        DE_isALUI;
wire        DE_isALUR;
wire        DE_isFENCE;
wire        DE_isSYS;
wire        DE_isSFENCEVMA;
wire        DE_isEBREAK;
wire        DE_isCSR;
wire        DE_isAMO;
wire        DE_isFPU;

wire [5:0]  DE_rdId;
wire [5:0]  DE_rs1Id;
wire [5:0]  DE_rs2Id;
wire [5:0]  DE_rs3Id;
wire [11:0] DE_csrId;
wire [31:0] DE_csrData;

wire [2:0]  DE_funct3;
wire [7:0]  DE_funct3_is;
wire [6:0]  DE_funct7;

wire [31:0] DE_Iimm;
wire [31:0] DE_Simm;
wire [31:0] DE_Bimm;
wire [31:0] DE_Uimm;

wire        DE_isRV32M;
wire        DE_isMUL;
wire        DE_isDIV;

wire        DE_wbEnable; // !isBranch && !isStore && rdId != 0

wire        DE_predictBranch;
wire [BP_ADDR_BITS-1:0] DE_bhtIndex;
wire [31:0] DE_predictRA;

localparam BP_ADDR_BITS = 12;
localparam BHT_SIZE = 1 << BP_ADDR_BITS;
localparam BH_BITS = 9;

DecodeUnit #(
        .BP_ADDR_BITS(BP_ADDR_BITS),
        .BHT_SIZE(BHT_SIZE),
        .BH_BITS(BH_BITS)
)decode(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .D_stall_i(D_stall),
        .D_flush_i(D_flush),
        .E_flush_i(E_flush),
        .E_stall_i(E_stall),
        .M_busy_i(M_busy),
        .E_takeBranch_i(E_takeBranch),
        .EM_PC_i(EM_PC),
        .D_satpWrite_o(D_satpWrite),
        .D_predictPC_o(D_predictPC),
        .D_PCprediction_o(D_PCprediction),
        .dataHazard_o(dataHazard),
        .D_isPrivileged_o(D_isPrivileged),
        .D_privilege_o(D_privilege),
        .D_data_fault_o(D_data_fault),
        .csrRAddr_o(csrRAddr),
        .csrRData_i(csrRData),
        .csrMStatus_i(csrMStatus),
        .csrMedeleg_i(csrMedeleg),
        .csrMideleg_i(csrMideleg),
        .csrMie_i(csrMie),
        .csrMtvec_i(csrMtvec),
        .csrMepc_i(csrMepc),
        .csrMCause_i(csrMCause),
        .csrMip_i(csrMip),
        .csrStvec_i(csrStvec),
        .csrSepc_i(csrSepc),
        .csrSCause_i(csrSCause),
        .csrMStatusSet_o(csrMStatusSet),
        .csrMepcSet_o(csrMepcSet),
        .csrMCauseSet_o(csrMCauseSet),
        .csrSepcSet_o(csrSepcSet),
        .csrSCauseSet_o(csrSCauseSet),
        .csrTrapSetEn_o(csrTrapSetEn),
        .page_fault_i(page_fault_i),
        .FD_PC_i(FD_PC),
        .FD_instr_i(FD_instr),
        .FD_isRV32C_i(FD_isRV32C),
        .FD_nop_i(FD_nop),
        .DE_PC_o(DE_PC),
        .DE_instr_o(DE_instr),
        .DE_isRV32C_o(DE_isRV32C),
        .DE_nop_o(DE_nop),
        .DE_priv_o(DE_priv),
        .DE_isLUI_o(DE_isLUI),
        .DE_isAUIPC_o(DE_isAUIPC),
        .DE_isJAL_o(DE_isJAL),
        .DE_isJALR_o(DE_isJALR),
        .DE_isBranch_o(DE_isBranch),
        .DE_isLoad_o(DE_isLoad),
        .DE_isStore_o(DE_isStore),
        .DE_isALUI_o(DE_isALUI),
        .DE_isALUR_o(DE_isALUR),
        .DE_isFENCE_o(DE_isFENCE),
        .DE_isSYS_o(DE_isSYS),
        .DE_isSFENCEVMA_o(DE_isSFENCEVMA),
        .DE_isEBREAK_o(DE_isEBREAK),
        .DE_isCSR_o(DE_isCSR),
        .DE_isAMO_o(DE_isAMO),
        .DE_isFPU_o(DE_isFPU),
        .DE_rdId_o(DE_rdId),
        .DE_rs1Id_o(DE_rs1Id),
        .DE_rs2Id_o(DE_rs2Id),
        .DE_rs3Id_o(DE_rs3Id),
        .DE_csrId_o(DE_csrId),
        .DE_csrData_o(DE_csrData),
        .DE_funct3_o(DE_funct3),
        .DE_funct3_is_o(DE_funct3_is),
        .DE_funct7_o(DE_funct7),
        .DE_Iimm_o(DE_Iimm),
        .DE_Simm_o(DE_Simm),
        .DE_Bimm_o(DE_Bimm),
        .DE_Uimm_o(DE_Uimm),
        .DE_isRV32M_o(DE_isRV32M),
        .DE_isMUL_o(DE_isMUL),
        .DE_isDIV_o(DE_isDIV),
        .DE_wbEnable_o(DE_wbEnable),
        .DE_predictBranch_o(DE_predictBranch),
        .DE_bhtIndex_o(DE_bhtIndex),
        .DE_predictRA_o(DE_predictRA)
);

/******************************************************************************
 ---------------------------------EXECUTE UNIT--------------------------------*
 ******************************************************************************/
wire [31:0] EM_PC;
wire        EM_nop;
wire [1:0]  EM_priv;
wire        EM_isLoad;
wire        EM_isStore;
wire        EM_isCSR;
wire        EM_isCSRWrite;
wire        EM_isAMO;
wire        EM_isFENCE;
wire        EM_isSFENCEVMA;
wire [5:0]  EM_rdId;
wire [5:0]  EM_rs1Id;
wire [5:0]  EM_rs2Id;
wire [11:0] EM_csrId;
wire [63:0] EM_rs2;
wire [2:0]  EM_funct3;
wire [6:0]  EM_funct7;

wire [63:0] EM_Eresult;
wire [31:0] EM_addr;
wire [63:0] EM_Mdata;
wire [31:0] EM_csrData;
wire        EM_wbEnable;

/*verilator public_flat_rw_on*/
wire        E_correctPC;
wire [31:0] E_PCcorrection;
wire        E_takeBranch;
wire        EF_correctPC;
wire [31:0] EF_PCcorrection;
wire        aluBusy;
/*verilator public_off*/

ExecuteUnit execute(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .E_stall_i(E_stall),
        .M_flush_i(M_flush),
        .dataHazard_i(dataHazard),
        .HALT_o(HALT),
        .E_takeBranch_o(E_takeBranch),
        .E_correctPC_o(E_correctPC),
        .E_PCcorrection_o(E_PCcorrection),
        .EF_correctPC_o(EF_correctPC),
        .EF_PCcorrection_o(EF_PCcorrection),
        .E_satpWrite_o(E_satpWrite),
        .E_satpUpdate_o(E_satpUpdate),
        .aluBusy_o(aluBusy),
        .rs1Id_o(rs1Id),
        .rs2Id_o(rs2Id),
        .rs3Id_o(rs3Id),
        .rs1Data_i(rs1Data),
        .rs2Data_i(rs2Data),
        .rs3Data_i(rs3Data),
        .csrWAddr_o(csrWAddr),
        .csrWData_o(csrWData),
        .csrWEnable_o(csrWEnable),
        .csrFFlagsSet_o(csrFFlagsSet),
        .csrFRM_i(csrFRM),
        .csrSatp_i(csrSatp),
        .csrMStatus_i(csrMStatus),
        .DC_rStrb_o(DC_rStrb_o),
        .DC_rAddr_o(DC_rAddr),
        .DC_rSatp_o(DC_rSatp),
        .DC_rPriv_o(DC_rPriv),
        .DC_rMxr_o(DC_rMxr),
        .DC_rSum_o(DC_rSum),
        .DC_validReady_i(DC_validReady_i),
        .MW_wbEnable_i(MW_wbEnable),
        .MW_rdId_i(MW_rdId),
        .MW_wbData_i(MW_wbData),
        .DE_PC_i(DE_PC),
        .DE_instr_i(DE_instr),
        .DE_isRV32C_i(DE_isRV32C),
        .DE_nop_i(DE_nop),
        .DE_priv_i(DE_priv),
        .DE_isLUI_i(DE_isLUI),
        .DE_isAUIPC_i(DE_isAUIPC),
        .DE_isJAL_i(DE_isJAL),
        .DE_isJALR_i(DE_isJALR),
        .DE_isBranch_i(DE_isBranch),
        .DE_isLoad_i(DE_isLoad),
        .DE_isStore_i(DE_isStore),
        .DE_isALUI_i(DE_isALUI),
        .DE_isALUR_i(DE_isALUR),
        .DE_isFENCE_i(DE_isFENCE),
        .DE_isSYS_i(DE_isSYS),
        .DE_isSFENCEVMA_i(DE_isSFENCEVMA),
        .DE_isEBREAK_i(DE_isEBREAK),
        .DE_isCSR_i(DE_isCSR),
        .DE_isAMO_i(DE_isAMO),
        .DE_isFPU_i(DE_isFPU),
        .DE_rdId_i(DE_rdId),
        .DE_rs1Id_i(DE_rs1Id),
        .DE_rs2Id_i(DE_rs2Id),
        .DE_rs3Id_i(DE_rs3Id),
        .DE_csrId_i(DE_csrId),
        .DE_csrData_i(DE_csrData),
        .DE_funct3_i(DE_funct3),
        .DE_funct3_is_i(DE_funct3_is),
        .DE_funct7_i(DE_funct7),
        .DE_Iimm_i(DE_Iimm),
        .DE_Simm_i(DE_Simm),
        .DE_Bimm_i(DE_Bimm),
        .DE_Uimm_i(DE_Uimm),
        .DE_isRV32M_i(DE_isRV32M),
        .DE_isMUL_i(DE_isMUL),
        .DE_isDIV_i(DE_isDIV),
        .DE_wbEnable_i(DE_wbEnable),
        .DE_predictBranch_i(DE_predictBranch),
        .DE_predictRA_i(DE_predictRA),
        .EM_PC_o(EM_PC),
        .EM_nop_o(EM_nop),
        .EM_priv_o(EM_priv),
        .EM_isLoad_o(EM_isLoad),
        .EM_isStore_o(EM_isStore),
        .EM_isCSR_o(EM_isCSR),
        .EM_isCSRWrite_o(EM_isCSRWrite),
        .EM_isAMO_o(EM_isAMO),
        .EM_isFENCE_o(EM_isFENCE),
        .EM_isSFENCEVMA_o(EM_isSFENCEVMA),
        .EM_rdId_o(EM_rdId),
        .EM_rs1Id_o(EM_rs1Id),
        .EM_rs2Id_o(EM_rs2Id),
        .EM_csrId_o(EM_csrId),
        .EM_rs2_o(EM_rs2),
        .EM_funct3_o(EM_funct3),
        .EM_funct7_o(EM_funct7),
        .EM_Eresult_o(EM_Eresult),
        .EM_addr_o(EM_addr),
        .EM_csrData_o(EM_csrData),
        .EM_wbEnable_o(EM_wbEnable)
);

/******************************************************************************
 ------------------------------MEMORY ACCESS UNIT-----------------------------*
 ******************************************************************************/
wire [5:0]  MW_rdId;
wire [63:0] MW_wbData;
wire        MW_wbEnable;

wire        M_busy;

MemoryUnit memory(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .M_busy_o(M_busy),
        .tlb_flush_o(tlb_flush_o),
        .DC_rData_i(DC_rData_i),
        .DC_wAddr_o(DC_wAddr),
        .DC_flush_o(DC_flush_o),
        .DC_wData_o(DC_wData_o),
        .DC_wMask_o(DC_wMask_o),
        .DC_wSatp_o(DC_wSatp),
        .DC_wPriv_o(DC_wPriv),
        .DC_wMxr_o(DC_wMxr),
        .DC_wSum_o(DC_wSum),
        .DC_validReady_i(DC_validReady_i),
        .csrSatp_i(csrSatp),
        .csrMStatus_i(csrMStatus),
        .csrInstStep_o(csrInstStep),
        .EM_nop_i(EM_nop),
        .EM_priv_i(EM_priv),
        .EM_isLoad_i(EM_isLoad),
        .EM_isStore_i(EM_isStore),
        .EM_isCSR_i(EM_isCSR),
        .EM_isAMO_i(EM_isAMO),
        .EM_isFENCE_i(EM_isFENCE),
        .EM_isSFENCEVMA_i(EM_isSFENCEVMA),
        .EM_rdId_i(EM_rdId),
        .EM_rs1Id_i(EM_rs1Id),
        .EM_rs2Id_i(EM_rs2Id),
        .EM_csrId_i(EM_csrId),
        .EM_rs2_i(EM_rs2),
        .EM_funct3_i(EM_funct3),
        .EM_funct7_i(EM_funct7),
        .EM_Eresult_i(EM_Eresult),
        .EM_addr_i(EM_addr),
        .EM_csrData_i(EM_csrData),
        .EM_wbEnable_i(EM_wbEnable),
        .MW_rdId_o(MW_rdId),
        .MW_wbData_o(MW_wbData),
        .MW_wbEnable_o(MW_wbEnable)
);
/******************************************************************************
 -------------------------------WRITE BACK UNIT--------------------------------
 ******************************************************************************/

WriteBackUnit writeback(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rdId_o(rdId),
        .rdData_o(rdData),
        .MW_rdId_i(MW_rdId),
        .MW_wbData_i(MW_wbData),
        .MW_wbEnable_i(MW_wbEnable)
);

endmodule

