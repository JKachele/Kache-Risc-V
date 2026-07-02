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
        output wire         DMemValidReady_o,

        // SPI Flash
        output wire        spiClk_o,
        output wire        spiCs_o,
        inout  wire        spiMosi_io,
        input  wire        spiMiso_i
        // inout  wire [3:0]  spiData_io
);

reg  [31:0]  DMemAddr;
reg  [31:0]  IMemAddr;

wire [255:0] SDRamRData = 256'b0;
wire         SDRamRBusy;
wire [7:0]   SDRamWMask;
wire [63:0]  SDRamInstr = 64'b0;
wire         SDRamIBusy;

wire [255:0] SPI_RData;
wire         SPI_RBusy;
wire [255:0] SPI_Instr;
wire         SPI_IBusy;

reg  [255:0] BRamRData;
reg  [255:0] BRamInstr;
wire [7:0]   BRamWMask;

assign DMemValidReady_o = ~((M_isSPI_r & SPI_RBusy) | (M_isSDRAM_r & SDRamRBusy));

// assign IMemValid_o = ~((M_isSPI_i & SPI_IBusy) | (M_isSDRAM_i & SDRamIBusy) | SPI_Busy);
assign IMemValid_o = 1'b1;

/*-------------------------------- Memory Map --------------------------------*/
// Use memory map to determine destination
wire M_isSDRAM_r = (DMemAddr[31:28] == 4'b0000);
wire M_isSDRAM_i = (IMemAddr[31:28]  == 4'b0000);
wire M_isSDRAM_w = (DMemAddr_i[31:28] == 4'b0000);
wire M_isSPI_r   = (DMemAddr[31:28] == 4'b0001);
wire M_isSPI_w   = (DMemAddr_i[31:28] == 4'b0001);
wire M_isSPI_i   = (IMemAddr[31:28] == 4'b0001);
wire M_isBRAM_r  = (DMemAddr[31:28] == 4'b0111);
wire M_isBRAM_i  = (IMemAddr[31:28]  == 4'b0111);
wire M_isBRAM_w  = (DMemAddr_i[31:28] == 4'b0111);

// Use memory map to determine destination
// Reads
assign DMemRData_o = M_isSDRAM_r ? SDRamRData :
                    (M_isSPI_r   ? SPI_RData  : BRamRData);
// assign DMemRData_o = BRamRData;

// assign IMemData_o  = M_isSDRAM_i ? SDRamInstr : BRamInstr;
assign IMemData_o  = BRamInstr;
// assign IMemData_o  = SPI_Instr;

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


/*-------------------------------- Block Ram --------------------------------*/
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


/*-------------------------------- SPI Flash --------------------------------*/
wire [255:0] SPI_Data;
wire         SPI_Busy;

// assign SPI_RData = {SPI_Data[7:0],   SPI_Data[15:8],  SPI_Data[23:16], SPI_Data[31:24],
//                     SPI_Data[39:32], SPI_Data[47:40], SPI_Data[55:48], SPI_Data[63:56]};
// assign SPI_Instr = SPI_Data[255:192];
assign SPI_Instr = SPI_Data;
assign SPI_RData = SPI_Data;

// dspiFlash flash(
//         .clk_i(clk_i),
//         .reset_i(reset_i),
//         .rstrb_i(IMemStrb_i),
//         .raddr_i(IMemAddr_i[23:0]),
//         .numBytes_i(32),
//         .rdata_o(SPI_Data),
//         .rbusy_o(SPI_Busy),
//         .spiClk_o(spiClk_o),
//         .spiCs_o(spiCs_o),
//         .spiMosi_io(spiMosi_io),
//         .spiMiso_i(spiMiso_i)
//         // .spiData_io(spiData_io)
// );

dspiFlash flash(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rstrb_i(((DMemAddr_i[31:28] == 4'b0001) || M_isSPI_r) & DMemRStrb_i),
        .raddr_i(DMemAddr_i[23:0]),
        .numBytes_i(32),
        .rdata_o(SPI_Data),
        .rbusy_o(SPI_RBusy),
        .spiClk_o(spiClk_o),
        .spiCs_o(spiCs_o),
        .spiMosi_io(spiMosi_io),
        .spiMiso_i(spiMiso_i)
        // .spiData_io(spiData_io)
);

endmodule
/* verilator lint_on WIDTH */

