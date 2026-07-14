/*************************************************
 *File----------Memory.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:59:49 UTC
 ************************************************/

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

        // AXI4 Interface
        output reg  [31:0]  m_axi_awaddr_o,
        output wire [ 7:0]  m_axi_awlen_o,
        output wire [ 3:0]  m_axi_awid_o,
        output reg          m_axi_awvalid_o,
        input  wire         m_axi_awready_i,
        output reg  [31:0]  m_axi_wdata_o,
        output reg  [ 3:0]  m_axi_wstrb_o,
        output reg          m_axi_wlast_o,
        output reg          m_axi_wvalid_o,
        input  wire         m_axi_wready_i,
        input  wire [ 1:0]  m_axi_bresp_i,
        input  wire [ 3:0]  m_axi_bid_i,
        input  wire         m_axi_bvalid_i,
        output wire         m_axi_bready_o,

        output reg  [31:0]  m_axi_araddr_o,
        output wire [ 7:0]  m_axi_arlen_o,
        output wire [ 3:0]  m_axi_arid_o,
        output reg          m_axi_arvalid_o,
        input  wire         m_axi_arready_i,
        input  wire [31:0]  m_axi_rdata_i,
        input  wire [ 1:0]  m_axi_rresp_i,
        input  wire         m_axi_rlast_i,
        input  wire [ 3:0]  m_axi_rid_i,
        input  wire         m_axi_rvalid_i,
        output reg          m_axi_rready_o
);

reg  [31:0]  DMemAddr;
reg  [31:0]  IMemAddr;

reg  [255:0] SDRamRData;
reg  [255:0] SDRamInstr;
wire [7:0]   SDRamWMask;
wire         SDRamBusy = 1'b0; // (SDR_State != IDLE);

reg  [255:0] BRamRData;
reg  [255:0] BRamInstr;
wire [7:0]   BRamWMask;

assign DMemValidReady_o = ~((M_isSDRAM_r | M_isSDRAM) & SDRamBusy);

assign IMemValid_o = ~(M_isSDRAM_i & SDRamBusy);
// assign IMemValid_o = 1'b1;

/*-------------------------------- Memory Map --------------------------------*/
// Use memory map to determine destination
wire M_isSDRAM_r = (DMemAddr[31:28] == 4'b0000);
wire M_isSDRAM_i = (IMemAddr[31:28]  == 4'b0000);
wire M_isSDRAM   = (DMemAddr_i[31:28] == 4'b0000);
wire M_isBRAM_r  = (DMemAddr[31:28] == 4'b0111);
wire M_isBRAM_i  = (IMemAddr[31:28]  == 4'b0111);
wire M_isBRAM    = (DMemAddr_i[31:28] == 4'b0111);

// Use memory map to determine destination
// Reads
assign DMemRData_o = M_isSDRAM_r ? SDRamRData : BRamRData;

assign IMemData_o  = M_isSDRAM_i ? SDRamInstr : BRamInstr;

// Writes
assign SDRamWMask = {8{M_isSDRAM}} & DMemWMask_i;
assign BRamWMask  = {8{M_isBRAM}} & DMemWMask_i;

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

always @(posedge clk_i) begin
        if (|SDRamWMask)
                SDRAM[DMemAddr_i[17:5]] <= DMemWData_i;
end

always @(posedge clk_i) begin
        if (reset_i) begin
                SDRamRData <= 256'b0;
                SDRamInstr <= 256'b0;
        end
        if (DMemRStrb_i) begin
                SDRamRData <= SDRAM[DMemAddr_i[17:5]];
        end
        if (IMemStrb_i) begin
                SDRamInstr <= SDRAM[IMemAddr_i[17:5]];
        end
end
// wire isSDRamRead  =  DMemRStrb_i & M_isSDRAM;
// wire isSDRamWrite = |DMemWMask_i & M_isSDRAM;
// wire isSDRamInstr =  IMemStrb_i  & (IMemAddr_i[31:28] == 4'b0000);
//
// reg [3:0]   axiCounter;
// reg [255:0] SDRamWData;
// reg         SDRamDataReady;
// reg         SDRamInstrReady;
//
// localparam IDLE  = 2'b00;
// localparam READ  = 2'b01;
// localparam WRITE = 2'b10;
// localparam INSTR = 2'b11;
//
// reg [1:0] SDR_State = IDLE;
// always @(posedge clk_i) begin
//         if (reset_i) begin
//                 SDR_State <= IDLE;
//                 m_axi_awaddr_o  <= 32'b0;
//                 m_axi_awvalid_o <= 1'b0;
//                 m_axi_wdata_o   <= 32'b0;
//                 m_axi_wstrb_o   <= 4'b0;
//                 m_axi_wlast_o   <= 1'b0;
//                 m_axi_wvalid_o  <= 1'b0;
//                 m_axi_araddr_o  <= 32'b0;
//                 m_axi_arvalid_o <= 1'b0;
//                 m_axi_rready_o  <= 1'b0;
//         end else begin
//                 if (SDR_State == IDLE) begin
//                         SDRamDataReady <= 1'b0;
//                         SDRamInstrReady <= 1'b0;
//                         if (isSDRamRead) begin
//                                 SDR_State <= READ;
//                                 m_axi_araddr_o  <= DMemAddr_i;
//                                 m_axi_arvalid_o <= 1'b1;
//                                 m_axi_rready_o  <= 1'b1;
//                         end else if (isSDRamWrite) begin
//                                 SDR_State <= WRITE;
//                                 m_axi_awaddr_o  <= DMemAddr_i;
//                                 m_axi_awvalid_o <= 1'b1;
//                                 m_axi_wdata_o   <= DMemWData_i[31:0];
//                                 m_axi_wstrb_o   <= 4'hF;
//                                 m_axi_wvalid_o  <= 1'b1;
//                                 SDRamWData <= {32'b0, DMemWData_i[255:32]};
//                                 axiCounter <= 4'd8;
//                         end else if (isSDRamInstr) begin
//                                 SDR_State <= INSTR;
//                                 m_axi_araddr_o  <= IMemAddr_i;
//                                 m_axi_arvalid_o <= 1'b1;
//                                 m_axi_rready_o  <= 1'b1;
//                         end
//                 end else if (SDR_State == READ) begin
//                         if (m_axi_arready_i)
//                                 m_axi_arvalid_o <= 1'b0;
//                         if (m_axi_rvalid_i) begin
//                                 SDRamRData <= {m_axi_rdata_i, SDRamRData[255:32]};
//                                 if (m_axi_rlast_i) begin
//                                         m_axi_rready_o <= 1'b0;
//                                         SDRamDataReady <= 1'b1;
//                                         if (~SDRamInstrReady & isSDRamInstr) begin
//                                                 SDR_State <= INSTR;
//                                                 m_axi_araddr_o  <= IMemAddr_i;
//                                                 m_axi_arvalid_o <= 1'b1;
//                                                 m_axi_rready_o  <= 1'b1;
//                                         end else begin
//                                                 SDR_State <= IDLE;
//                                         end
//                                 end
//                         end
//                 end else if (SDR_State == WRITE) begin
//                         if (m_axi_awready_i)
//                                 m_axi_awvalid_o <= 1'b0;
//                         if (m_axi_wready_i) begin
//                                 m_axi_wdata_o   <= SDRamWData[31:0];
//                                 SDRamWData <= {32'b0, SDRamWData[255:32]};
//                                 axiCounter <= axiCounter - 1;
//                                 if (axiCounter == 1) begin
//                                         m_axi_wlast_o   <= 1'b1;
//                                 end
//                                 if (axiCounter == 0) begin
//                                         m_axi_wlast_o   <= 1'b0;
//                                         m_axi_wvalid_o  <= 1'b0;
//                                         SDRamDataReady <= 1'b1;
//                                         if (~SDRamInstrReady & isSDRamInstr) begin
//                                                 SDR_State <= INSTR;
//                                                 m_axi_araddr_o  <= IMemAddr_i;
//                                                 m_axi_arvalid_o <= 1'b1;
//                                                 m_axi_rready_o  <= 1'b1;
//                                         end else begin
//                                                 SDR_State <= IDLE;
//                                         end
//                                 end
//                         end
//                 end else if (SDR_State == INSTR) begin
//                         if (m_axi_arready_i)
//                                 m_axi_arvalid_o <= 1'b0;
//                         if (m_axi_rvalid_i) begin
//                                 SDRamInstr <= {m_axi_rdata_i, SDRamInstr[255:32]};
//                                 if (m_axi_rlast_i) begin
//                                         m_axi_rready_o <= 1'b0;
//                                         SDRamInstrReady <= 1'b1;
//                                         if (~SDRamDataReady & isSDRamRead) begin
//                                                 SDR_State <= READ;
//                                                 m_axi_araddr_o  <= DMemAddr_i;
//                                                 m_axi_arvalid_o <= 1'b1;
//                                                 m_axi_rready_o  <= 1'b1;
//                                         end else if (~SDRamDataReady & isSDRamWrite) begin
//                                                 SDR_State <= WRITE;
//                                                 m_axi_awaddr_o  <= DMemAddr_i;
//                                                 m_axi_awvalid_o <= 1'b1;
//                                                 m_axi_wdata_o   <= DMemWData_i[31:0];
//                                                 m_axi_wstrb_o   <= 4'hF;
//                                                 m_axi_wvalid_o  <= 1'b1;
//                                                 SDRamWData <= {32'b0, DMemWData_i[255:32]};
//                                                 axiCounter <= 4'd8;
//                                         end else begin
//                                                 SDR_State <= IDLE;
//                                         end
//                                 end
//                         end
//                 end else begin
//                         SDR_State <= IDLE;
//                 end
//         end
// end
//
// assign m_axi_awid_o = 4'b0;
// assign m_axi_bready_o = 1'b1;
// assign m_axi_awlen_o = 8'd7; // 8 byte burst
// assign m_axi_arlen_o = 8'd7; // 8 byte burst

/*-------------------------------- Block RAM --------------------------------*/
reg [255:0] BRAM [0:1023];

initial begin
        $readmemh("../bin/BRAM.hex",BRAM);
end

always @(posedge clk_i) begin
        if (|BRamWMask)
                BRAM[DMemAddr_i[14:5]] <= DMemWData_i;
end

always @(posedge clk_i) begin
        if (reset_i) begin
                BRamRData <= 256'b0;
                BRamInstr <= 256'b0;
        end
        if (DMemRStrb_i) begin
                BRamRData <= BRAM[DMemAddr_i[14:5]];
        end
        if (IMemStrb_i) begin
                BRamInstr <= BRAM[IMemAddr_i[14:5]];
        end
end

endmodule

