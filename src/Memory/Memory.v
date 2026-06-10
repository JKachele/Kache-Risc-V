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
        input  wire        IMemStrb_i,
        input  wire [31:0] IMemAddr_i,
        output wire [63:0] IMemData_o,
        output wire        IMemValid_o,

        input  wire        DMemRStrb_i,
        input  wire [31:0] DMemRAddr_i,
        output wire [31:0] DMemRData_o,
        output wire        DMemRBusy_o,
        input  wire [31:0] DMemWAddr_i,
        input  wire [31:0] DMemWData_i,
        input  wire [3:0]  DMemWMask_i,
        output wire        DMemWBusy_o,

        // IO
        output wire [3:0]  leds_o,
        output wire        txd_o,
        // SPI Flash
        output wire        spiClk_o,
        output wire        spiCs_o,
        inout  wire        spiMosi_io,
        input  wire        spiMiso_i
        // inout  wire [3:0]  spiData_io
);

reg  [31:0] DMemRAddr;
reg  [31:0] IMemAddr;

wire [31:0] SDRamRData = 32'b0;
wire        SDRamRBusy;
wire [4:0]  SDRamWMask;
wire [63:0] SDRamInstr = 64'b0;
wire        SDRamIBusy;

wire [31:0] SPI_RData;
wire        SPI_RBusy;
wire [63:0] SPI_Instr;
wire        SPI_IBusy;

reg  [31:0] BRamRData;
reg  [63:0] BRamInstr;
wire [4:0]  BRamWMask;
wire [31:0] IO_RData;
wire        IO_Wr;

assign DMemRBusy_o = (M_isSPI_r & SPI_RBusy) | (M_isSDRAM_r & SDRamRBusy);

reg [6:0] testCount;
wire testBusy = |testCount;
assign IMemValid_o = ~((M_isSPI_i & SPI_IBusy) | (M_isSDRAM_i & SDRamIBusy) | SPI_Busy | testBusy);

/*-------------------------------- Memory Map --------------------------------*/
// Use memory map to determine destination
wire M_isSDRAM_r = (DMemRAddr[31:28] == 4'b0000);
wire M_isSDRAM_i = (IMemAddr[31:28]  == 4'b0000);
wire M_isSDRAM_w = (DMemWAddr_i[31:28] == 4'b0000);
wire M_isSPI_r   = (DMemRAddr[31:28] == 4'b0001);
wire M_isSPI_w   = (DMemWAddr_i[31:28] == 4'b0001);
wire M_isSPI_i   = (IMemAddr[31:28] == 4'b0001);
wire M_isBRAM_r  = (DMemRAddr[31:28] == 4'b1111);
wire M_isBRAM_i  = (IMemAddr[31:28]  == 4'b1111);
wire M_isBRAM_w  = (DMemWAddr_i[31:28] == 4'b1111);
wire M_isIO_r    = (!M_isBRAM_r && DMemRAddr[31]);
wire M_isIO_w    = (!M_isBRAM_w && DMemWAddr_i[31]);

// Use memory map to determine destination
// Reads
assign DMemRData_o = M_isSDRAM_r ? SDRamRData :
                    (M_isSPI_r   ? SPI_RData  :
                    (M_isBRAM_r  ? BRamRData  : IO_RData));

// assign IMemData_o  = M_isSDRAM_i ? SDRamInstr : BRamInstr;
// assign IMemData_o  = BRamInstr;
assign IMemData_o  = SPI_Instr;

// Writes
assign SDRamWMask = {4{M_isSDRAM_w}} & DMemWMask_i;
assign BRamWMask  = {4{M_isBRAM_w}} & DMemWMask_i;
assign IO_Wr = (M_isIO_w) & (|DMemWMask_i);

always @(posedge clk_i) begin
        if (reset_i) begin
                DMemRAddr <= rvec_i;
                IMemAddr  <= rvec_i;
        end
        if (DMemRStrb_i)
                DMemRAddr <= DMemRAddr_i;
        if (IMemStrb_i)
                IMemAddr  <= IMemAddr_i;
end


/*-------------------------------- Block Ram --------------------------------*/
reg [63:0] BRAM [0:65535];

initial begin
        $readmemh("../bin/BRAM.hex",BRAM);
end

// Instruction ROM: Can be alligned to 16 bits or 32 bits
// wire [31:0] BRamInstr_1 = BRAM[IMemAddr_i[18:2]];
// wire [31:0] BRamInstr_2 = BRAM[IMemAddr_i[18:2] + 1];
// wire [63:0] BRamInstr_w = {BRamInstr_2, BRamInstr_1};
wire [63:0] BRamInstr_w = BRAM[IMemAddr_i[18:3]];

// Data RAM: All alligned to 32 bits
wire [63:0] BRamRData_w = BRAM[DMemRAddr_i[18:3]];

wire [15:0] wordAddr = DMemWAddr_i[18:3];
always @(posedge clk_i) begin
        if (DMemWAddr_i[2]) begin
                if (BRamWMask[0]) BRAM[wordAddr][39:32] <= DMemWData_i[ 7:0 ];
                if (BRamWMask[1]) BRAM[wordAddr][47:40] <= DMemWData_i[15:8 ];
                if (BRamWMask[2]) BRAM[wordAddr][55:48] <= DMemWData_i[23:16];
                if (BRamWMask[3]) BRAM[wordAddr][63:56] <= DMemWData_i[31:24];
        end else begin
                if (BRamWMask[0]) BRAM[wordAddr][ 7:0 ] <= DMemWData_i[ 7:0 ];
                if (BRamWMask[1]) BRAM[wordAddr][15:8 ] <= DMemWData_i[15:8 ];
                if (BRamWMask[2]) BRAM[wordAddr][23:16] <= DMemWData_i[23:16];
                if (BRamWMask[3]) BRAM[wordAddr][31:24] <= DMemWData_i[31:24];
        end
end

always @(posedge clk_i) begin
        if (reset_i) begin
                BRamRData <= 32'b0;
                BRamInstr <= 64'b0;
        end
        if (DMemRStrb_i) begin
                BRamRData <= DMemRAddr_i[2] ? BRamRData_w[63:32] : BRamRData_w[31:0];
        end
        if (IMemStrb_i) begin
        //         testCount <= 7'd65;
        // end else if (testCount > 1) begin
        //         testCount <= testCount - 1;
        // end else begin
                testCount <= 7'b0;
                // BRamInstr <= IMemAddr_i[1] ? BRamInstr_w[47:16] : BRamInstr_w[31:0];
                BRamInstr <= BRamInstr_w;
        end
end


/*-------------------------------- SPI Flash --------------------------------*/
wire [255:0] SPI_RawData;
wire         SPI_Busy;

assign SPI_RData = {SPI_RawData[7:0],   SPI_RawData[15:8],  SPI_RawData[23:16], SPI_RawData[31:24]};
assign SPI_Instr = {SPI_RawData[7:0],   SPI_RawData[15:8],  SPI_RawData[23:16], SPI_RawData[31:24],
                    SPI_RawData[39:32], SPI_RawData[47:40], SPI_RawData[55:48], SPI_RawData[63:56]};

dspiFlash flash(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rstrb_i(IMemStrb_i),
        .raddr_i(IMemAddr_i[23:0]),
        .numBytes_i(8),
        .rdata_o(SPI_RawData),
        .rbusy_o(SPI_Busy),
        .spiClk_o(spiClk_o),
        .spiCs_o(spiCs_o),
        .spiMosi_io(spiMosi_io),
        .spiMiso_i(spiMiso_i)
        // .spiData_io(spiData_io)
);

// dspiFlash flash(
//         .clk_i(clk_i),
//         .reset_i(reset_i),
//         .rstrb_i(((DMemRAddr_i[31:28] == 4'b0001) || M_isSPI_r) & DMemRStrb_i),
//         .raddr_i(DMemRAddr_i[23:0]),
//         .numBytes_i(4),
//         .rdata_o(SPI_RawData),
//         .rbusy_o(SPI_RBusy),
//         .spiClk_o(spiClk_o),
//         .spiCs_o(spiCs_o),
//         .spiMosi_io(spiMosi_io),
//         .spiMiso_i(spiMiso_i)
//         // .spiData_io(spiData_io)
// );


/*-------------------------------- IO --------------------------------*/
IO io(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .IO_memRAddr_i(DMemRAddr_i),
        .IO_memRData_o(IO_RData),
        .IO_memWAddr_i(DMemWAddr_i),
        .IO_memWData_i(DMemWData_i[31:0]),
        .IO_memWr_i(IO_Wr),
        .leds_o(leds_o),
        .txd_o(txd_o)
);

endmodule
/* verilator lint_on WIDTH */

