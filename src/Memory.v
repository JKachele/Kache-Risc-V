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
        input  wire [31:0] IMemAddr_i,
        output wire [63:0] IMemData_o,
        input  wire [31:0] DMemRAddr_i,
        output wire [63:0] DMemRData_o,
        input  wire [31:0] DMemWAddr_i,
        input  wire [63:0] DMemWData_i,
        input  wire [4:0]  DMemWMask_i,

        // IO
        output wire [3:0]  leds_o,
        output wire        txd_o
);

wire [63:0] SDRamRData = 64'b0;
wire [63:0] SDRamInstr = 64'b0;
wire [4:0]  SDRamWMask;
wire [63:0] SPI_RData = 64'b0;
wire [63:0] BRamRData;
wire [63:0] BRamInstr;
wire [4:0]  BRamWMask;
wire [31:0] IO_RData;
wire        IO_Wr;

/*-------------------------------- Memory Map --------------------------------*/
// Use memory map to determine destination
wire M_isSDRAM_r = (DMemRAddr_i[31:28] == 4'b0000);
wire M_isSDRAM_i = (IMemAddr_i[31:28]  == 4'b0000);
wire M_isSDRAM_w = (DMemWAddr_i[31:28] == 4'b0000);
wire M_isSPI_r   = (DMemRAddr_i[31:28] == 4'b0001);
wire M_isSPI_w   = (DMemWAddr_i[31:28] == 4'b0001); // SPI Can't write, but still keeping this space
wire M_isBRAM_r  = (DMemRAddr_i[31:28] == 4'b1111);
wire M_isBRAM_i  = (IMemAddr_i[31:28]  == 4'b1111);
wire M_isBRAM_w  = (DMemWAddr_i[31:28] == 4'b1111);
wire M_isIO_r    = (!M_isSDRAM_r && !M_isSPI_r && !M_isBRAM_r);
wire M_isIO_w    = (!M_isSDRAM_w && !M_isSPI_w && !M_isBRAM_w);

// Use memory map to determine destination
// Reads
assign DMemRData_o = M_isSDRAM_r ? SDRamRData :
                    (M_isSPI_r   ? SPI_RData  :
                    (M_isBRAM_r  ? BRamRData  : IO_RData));

assign IMemData_o  = M_isSDRAM_i ? SDRamInstr : BRamInstr;

// Writes
assign SDRamWMask = {5{M_isSDRAM_w}} & DMemWMask_i;
assign BRamWMask  = {5{M_isBRAM_w}} & DMemWMask_i;
assign IO_Wr = (M_isIO_w) & (|DMemWMask_i);


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


/*-------------------------------- Block Ram --------------------------------*/
reg [31:0] BRAM [0:131071];

initial begin
        $readmemh("../bin/BRAM.hex",BRAM);
end

// Instruction ROM: Can be alligned to 16 bits or 32 bits
wire [31:0] IMemdata_1 = BRAM[IMemAddr_i[18:2]];
wire [31:0] IMemdata_2 = BRAM[IMemAddr_i[18:2] + 1];
assign BRamInstr = {IMemdata_2, IMemdata_1};

// Data RAM: All alligned to 32 bits
wire [31:0] DMemRData_1 = BRAM[DMemRAddr_i[18:2]];
wire [31:0] DMemRData_2 = BRAM[DMemRAddr_i[18:2] + 1];
assign BRamRData = {DMemRData_2, DMemRData_1};

wire [16:0] wordAddr = DMemWAddr_i[18:2];
always @(posedge clk_i) begin
        if (BRamWMask[0]) BRAM[wordAddr][ 7:0 ] <= DMemWData_i[ 7:0 ];
        if (BRamWMask[1]) BRAM[wordAddr][15:8 ] <= DMemWData_i[15:8 ];
        if (BRamWMask[2]) BRAM[wordAddr][23:16] <= DMemWData_i[23:16];
        if (BRamWMask[3]) BRAM[wordAddr][31:24] <= DMemWData_i[31:24];
        if (BRamWMask[4]) BRAM[wordAddr + 1]    <= DMemWData_i[63:32];
end

endmodule
/* verilator lint_on WIDTH */

