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
        output wire [31:0] IMemData_o,
        input  wire [31:0] DMemRAddr_i,
        output wire [31:0] DMemRData_o,
        input  wire [31:0] DMemWAddr_i,
        input  wire [31:0] DMemWData_i,
        input  wire [3:0]  DMemWMask_i,

        // IO
        output wire [3:0]  leds_o,
        output wire        txd_o
);

wire [31:0] BRamRData;
wire [3:0]  BRamWMask;
wire [31:0] IO_RData;
wire        IO_Wr;

// reg M_isSDRAM;
// reg M_isSPI;
// reg M_isBRAM;
// reg M_isIO2;
//
// always @(*) begin
//         M_isSDRAM = 1'b0;
//         M_isSPI   = 1'b0;
//         M_isIO2   = 1'b0;
//         M_isBRAM  = 1'b0;
//         case (EM_addr_i[31:28])
//                 4'b0000: M_isSDRAM = 1'b1;
//                 4'b0001: M_isSPI   = 1'b1;
//                 4'b1111: M_isBRAM  = 1'b1;
//                 default: M_isIO2   = 1'b1;
//         endcase
// end

// Use memory map to determine destination
// Reads
wire isIO_r  = DMemRAddr_i[22];
assign DMemRData_o = isIO_r ? IO_RData : BRamRData;

wire isIO_w  = DMemWAddr_i[22];
wire isRAM_w = !isIO_w;
assign BRamWMask = {4{isRAM_w}} & DMemWMask_i;
assign IO_Wr = (isIO_w) & (|DMemWMask_i);


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


/*---------------- Block Ram ----------------*/
reg [15:0] INSTMEM [0:32767];
reg [31:0] DATAMEM [0:131071];
// reg [31:0] DATAMEM [0:16383];

initial begin
        $readmemh("../bin/ROM.hex",INSTMEM);
        $readmemh("../bin/RAM.hex",DATAMEM);
end

// Instruction ROM: Can be alligned to 16 bits or 32 bits
wire [15:0] IMemdata_1 = INSTMEM[IMemAddr_i[31:1]];
wire [15:0] IMemdata_2 = INSTMEM[IMemAddr_i[31:1] + 1];
assign IMemData_o = {IMemdata_2, IMemdata_1};

// Data RAM: All alligned to 32 bits
// Subtract 0x10000 from address to allow room for Instruction memory addresses
wire [31:0] DMemRAddr = DMemRAddr_i - 32'h00010000;
wire [31:0] DMemWAddr = DMemWAddr_i - 32'h00010000;

assign BRamRData = DATAMEM[DMemRAddr[31:2]];

wire [29:0] wordAddr = DMemWAddr[31:2];
always @(posedge clk_i) begin
        if (BRamWMask[0]) DATAMEM[wordAddr][ 7:0 ] <= DMemWData_i[ 7:0 ];
        if (BRamWMask[1]) DATAMEM[wordAddr][15:8 ] <= DMemWData_i[15:8 ];
        if (BRamWMask[2]) DATAMEM[wordAddr][23:16] <= DMemWData_i[23:16];
        if (BRamWMask[3]) DATAMEM[wordAddr][31:24] <= DMemWData_i[31:24];
end

endmodule
/* verilator lint_on WIDTH */

