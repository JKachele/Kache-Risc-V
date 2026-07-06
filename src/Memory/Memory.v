/*************************************************
 *File----------Memory.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:59:49 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module Memory (
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire [31:0] rvec_i,

        input  wire         IMemStrb_i,
        input  wire [31:0]  IMemAddr_i,
        output wire [255:0] IMemData_o,
        output wire         IMemValid_o,

        input  wire [31:0]  DMemAddr_i,
        input  wire         DMemRStrb_i,
        input  wire [255:0] DMemWData_i,
        input  wire [7:0]   DMemWMask_i,
        output wire [255:0] DMemRData_o,
        output wire         DMemValidReady_o
);

reg  [31:0]  DMemAddr;
reg  [31:0]  IMemAddr;

reg  [255:0] SDRamRData;
wire         SDRamDBusy = 1'b0;
wire [7:0]   SDRamWMask;
reg  [63:0]  SDRamInstr;
wire         SDRamIBusy = 1'b0;

reg  [255:0] BRamRData;
reg  [255:0] BRamInstr;
wire [7:0]   BRamWMask;

assign DMemValidReady_o = ~((M_isSDRAM_r | M_isSDRAM_w) & SDRamDBusy);

assign IMemValid_o = ~(M_isSDRAM_i & SDRamIBusy);
// assign IMemValid_o = 1'b1;

/*-------------------------------- Memory Map --------------------------------*/
// Use memory map to determine destination
wire M_isSDRAM_r = (DMemAddr[31:28] == 4'b0000);
wire M_isSDRAM_i = (IMemAddr[31:28]  == 4'b0000);
wire M_isSDRAM_w = (DMemAddr_i[31:28] == 4'b0000);
wire M_isBRAM_r  = (DMemAddr[31:28] == 4'b0111);
wire M_isBRAM_i  = (IMemAddr[31:28]  == 4'b0111);
wire M_isBRAM_w  = (DMemAddr_i[31:28] == 4'b0111);

// Use memory map to determine destination
// Reads
assign DMemRData_o = M_isSDRAM_r ? SDRamRData : BRamRData;
// assign DMemRData_o = BRamRData;

// assign IMemData_o  = M_isSDRAM_i ? SDRamInstr : BRamInstr;
assign IMemData_o  = BRamInstr;

// Writes
assign SDRamWMask = {8{M_isSDRAM_w}} & DMemWMask_i;
assign BRamWMask  = {8{M_isBRAM_w}} & DMemWMask_i;

always @(posedge clk_i) begin
        if (reset_i) begin
                DMemAddr <= rvec_i;
                IMemAddr  <= rvec_i;
        end
        if (DMemRStrb_i)
                DMemAddr <= DMemAddr_i;
        if (IMemStrb_i)
                IMemAddr  <= IMemAddr_i;
end

/*-------------------------------- SDRAM --------------------------------*/
// For now will fake with block ram
reg [255:0] SDRAM [0:8191];

initial begin
        $readmemh("../bin/BRAM.hex", SDRAM);
end

always @(posedge clk_i) begin
        if (|SDRamWMask)
                SDRAM[DMemAddr_i[18:5]] <= DMemWData_i;
end

always @(posedge clk_i) begin
        if (reset_i) begin
                SDRamRData <= 64'b0;
                SDRamInstr <= 64'b0;
        end
        if (DMemRStrb_i) begin
                SDRamRData <= SDRAM[DMemAddr_i[18:5]];
        end
        if (IMemStrb_i) begin
                SDRamInstr <= SDRAM[IMemAddr_i[18:5]];
        end
end

/*-------------------------------- Block RAM --------------------------------*/
reg [255:0] BRAM [0:8191];

initial begin
        $readmemh("../bin/BRAM.hex",BRAM);
end

always @(posedge clk_i) begin
        if (|BRamWMask)
                BRAM[DMemAddr_i[18:5]] <= DMemWData_i;
end

always @(posedge clk_i) begin
        if (reset_i) begin
                BRamRData <= 64'b0;
                BRamInstr <= 64'b0;
        end
        if (DMemRStrb_i) begin
                BRamRData <= BRAM[DMemAddr_i[18:5]];
        end
        if (IMemStrb_i) begin
                BRamInstr <= BRAM[IMemAddr_i[18:5]];
        end
end

endmodule
/* verilator lint_on WIDTH */

