/*************************************************
 *File----------MemoryUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 19:42:17 UTC
 ************************************************/

module MemoryUnit (
        input  wire clk_i,
        input  wire reset_i,
        // Pipeline Control Signals
        output wire        M_busy_o,
        // Memory/IO Interface
        input  wire [31:0] DMemRData_i,
        input  wire        DMemRBusy_i,
        output wire [31:0] DMemWAddr_o,
        output wire [31:0] DMemWData_o,
        output wire [3:0]  DMemWMask_o,
        input  wire        DMemWBusy_i,
        // CSR Interface
        output wire [11:0] csrWAddr_o,
        output wire [31:0] csrWData_o,
        output wire        csrWEnable_o,
        output wire        csrInstStep_o,
        // Execute Unit Interface
        // input  wire [31:0] EM_PC_i,
        // input  wire [31:0] EM_instr_i,
        input  wire        EM_nop_i,
        input  wire        EM_isLoad_i,
        input  wire        EM_isStore_i,
        input  wire        EM_isCSR_i,
        input  wire        EM_isAMO_i,
        input  wire [5:0]  EM_rdId_i,
        input  wire [5:0]  EM_rs1Id_i,
        input  wire [5:0]  EM_rs2Id_i,
        input  wire [11:0] EM_csrId_i,
        input  wire [31:0] EM_rs2_i,
        input  wire [2:0]  EM_funct3_i,
        input  wire [6:0]  EM_funct7_i,
        input  wire [31:0] EM_Eresult_i,
        input  wire [31:0] EM_addr_i,
        // input  wire [63:0] EM_Mdata_i,
        input  wire [31:0] EM_CSRdata_i,
        input  wire        EM_wbEnable_i,
        // Writeback Unit Interface
        // output reg  [31:0] MW_PC_o,
        // output reg  [31:0] MW_instr_o,
        // output reg         MW_nop_o,
        output reg  [5:0]  MW_rdId_o,
        output reg  [31:0] MW_wbData_o,
        output reg         MW_wbEnable_o
);

/*---------------------LR/SC----------------------*/
reg [31:0] MM_reservedAddress;
reg        MM_reservedChanged;

wire M_isLR = EM_isAMO_i & (EM_funct7_i[6:2] == 5'b00010);
wire M_isSC = EM_isAMO_i & (EM_funct7_i[6:2] == 5'b00011);
wire M_isAMO = EM_isAMO_i & ~(M_isLR | M_isSC);

wire M_addressReserved = (EM_addr_i == MM_reservedAddress);

// Store Conditional succeeds if the address is reserved and hasent been modified
wire M_scWriteable = M_addressReserved & ~MM_reservedChanged;

always @(posedge clk_i) begin
        if (!M_busy_o) begin
                // Set reserved address and flag
                if (EM_isAMO_i & M_isLR) begin
                        MM_reservedAddress <= EM_addr_i;
                        MM_reservedChanged <= 1'b0;
                end
                // If any store to reserved address, set flag to changed
                else if ((EM_isStore_i || EM_isAMO_i) && M_addressReserved) begin
                        MM_reservedChanged <= 1'b1;
                end
        end
end

/*-----------Atomic Memory Instructions-----------*/
reg [31:0] M_amoOut;

wire [32:0] M_amoMinus = {1'b0, DMemRData_i[31:0]} + {1'b1, ~EM_rs2_i[31:0]} + 33'd1;
wire        M_amoLT  = (DMemRData_i[31] ^ EM_rs2_i[31]) ? DMemRData_i[31] : M_amoMinus[32];
wire        M_amoLTU = M_amoMinus[32];
always @(*) begin
        case (EM_funct7_i[6:2])
                5'h00: M_amoOut =             DMemRData_i[31:0] + EM_rs2_i[31:0]; // amoadd.w
                5'h01: M_amoOut =                                 EM_rs2_i[31:0]; // amoswap.w
                5'h04: M_amoOut =             DMemRData_i[31:0] ^ EM_rs2_i[31:0]; // amoxor.w
                5'h08: M_amoOut =             DMemRData_i[31:0] | EM_rs2_i[31:0]; // amoor.w
                5'h0c: M_amoOut =             DMemRData_i[31:0] & EM_rs2_i[31:0]; // amoand.w
                5'h10: M_amoOut =  M_amoLT  ? DMemRData_i[31:0] : EM_rs2_i[31:0]; // amomin.w
                5'h14: M_amoOut = !M_amoLT  ? DMemRData_i[31:0] : EM_rs2_i[31:0]; // amomax.w
                5'h18: M_amoOut =  M_amoLTU ? DMemRData_i[31:0] : EM_rs2_i[31:0]; // amominu.w
                5'h1c: M_amoOut = !M_amoLTU ? DMemRData_i[31:0] : EM_rs2_i[31:0]; // amomaxu.w
                default: M_amoOut = 32'b0;
        endcase
end

/*----------------------STORE---------------------*/
wire M_isB = (EM_funct3_i[1:0] == 2'b00);
wire M_isH = (EM_funct3_i[1:0] == 2'b01);

reg [31:0] M_storeData;
always @(*) begin
        if (M_isAMO) begin
                M_storeData = M_amoOut;
        end
        // Store byte only
        else if (EM_addr_i[0]) begin
                M_storeData = {4{EM_rs2_i[7:0]}};
        end
        // Store half for [31:16] or [15:0] or store byte for [23:16]
        else if (EM_addr_i[1]) begin
                M_storeData = {2{EM_rs2_i[15:0]}};
        end
        // Store word or store byte for [7:0]
        else begin
                M_storeData = EM_rs2_i;
        end
end

reg [3:0] M_storeMask;
always @(*) begin
        if (M_isB) begin
                if (EM_addr_i[1:0] == 2'b11)
                        M_storeMask = 4'b1000;
                else if (EM_addr_i[1:0] == 2'b10)
                        M_storeMask = 4'b0100;
                else if (EM_addr_i[1:0] == 2'b01)
                        M_storeMask = 4'b0010;
                else
                        M_storeMask = 4'b0001;
        end else if (M_isH) begin
                if (EM_addr_i[1])
                        M_storeMask = 4'b1100;
                else
                        M_storeMask = 4'b0011;
        end else begin
                M_storeMask = 4'b1111;
        end
end

reg M_storeEnable;
always @(*) begin
        if (EM_isStore_i || M_isAMO) begin
                M_storeEnable = 1'b1;
        end else if (M_isSC) begin
                if (M_scWriteable)
                        M_storeEnable = 1'b1;
                else
                        M_storeEnable = 1'b0;
        end else begin
                M_storeEnable = 1'b0;
        end
end

assign DMemWAddr_o = EM_addr_i;
assign DMemWData_o = M_storeData;
assign DMemWMask_o = {4{M_storeEnable}} & M_storeMask;

/*----------------------LOAD----------------------*/

assign M_busy_o = DMemRBusy_i;

// wire [15:0] M_memHalf = EM_addr_i[1] ? EM_Mdata_i[31:16] : EM_Mdata_i[15:0];
wire [15:0] M_memHalf = EM_addr_i[1] ? DMemRData_i[31:16] : DMemRData_i[15:0];
wire [7:0]  M_memByte = EM_addr_i[0] ? M_memHalf[15:8]  : M_memHalf[7:0];

// Sign expansion
// Based on funct3[2]: 0->sign expand, 1->unsigned
wire M_loadSign = !EM_funct3_i[2] & (M_isB ? M_memByte[7] : M_memHalf[15]);

reg [31:0] M_Mdata;
always @(*) begin
        if(M_isB)
                M_Mdata = {{24{M_loadSign}}, M_memByte};
        else if(M_isH)
                M_Mdata = {{16{M_loadSign}}, M_memHalf};
        else
                // M_Mdata = EM_Mdata_i;
                M_Mdata = DMemRData_i;
end


/*-----------------------CSR----------------------*/
assign csrWAddr_o   = EM_isCSR_i ? EM_csrId_i : {12{1'bZ}};
assign csrWData_o   = EM_isCSR_i ? EM_Eresult_i : {32{1'bZ}};
assign csrWEnable_o = EM_isCSR_i;

// Step up instruction counter if not a NOP and not stalled
assign csrInstStep_o  = ~MW_nop & ~M_busy_o;

/*------------------------------------------------*/
wire [31:0] M_wbData =
        M_isSC                     ? {31'b0, M_scWriteable} :
        (EM_isLoad_i | EM_isAMO_i) ? M_Mdata :
        EM_isCSR_i                 ? EM_CSRdata_i : EM_Eresult_i;

reg MW_nop;
always @(posedge clk_i) begin
        if (!M_busy_o) begin
                // MW_PC_o <= EM_PC_i;
                // MW_instr_o <= EM_instr_i;
                MW_nop <= EM_nop_i;

                MW_rdId_o <= EM_rdId_i;
                MW_wbData_o <= M_wbData;
                MW_wbEnable_o <= EM_wbEnable_i;
        end
end

endmodule

