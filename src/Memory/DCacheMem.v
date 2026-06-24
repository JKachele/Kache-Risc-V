/*************************************************
 *File----------DCacheMem.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Friday Jun 12, 2026 16:26:55 UTC
 ************************************************/

module DCacheMem #(
        parameter NSETS        = 256,
        parameter INDEX_WIDTH  = 8,
        parameter OFFSET_WIDTH = 5
)(
        input  wire                    clk_i,
        input  wire                    reset_i,

        input  wire [INDEX_WIDTH-1:0]  index_i,
        input  wire [OFFSET_WIDTH-1:0] offset_i,
        input  wire                    rden_i,
        input  wire [7:0]              wren_i,
        input  wire                    wrall_i,
        input  wire [255:0]            wdata_i,
        output reg  [255:0]            rdata_o
);

reg [255:0] mem [0:NSETS-1];

// Synchronous Reads
always @(posedge clk_i) begin
        if (rden_i)
                rdata_o <= mem[index_i];
end

// Synchronous Write Byte-Enable
reg         we;
reg [31:0]  be;
reg [255:0] wdata;

always @(*) begin
        // Default values
        we    = 1'b0;
        be    = 32'b0;
        wdata = 256'b0;

        // Full cache line write for cache misses
        if (wrall_i) begin
                we    = 1'b1;
                be    = 32'hFFFFFFFF;
                wdata = wdata_i;
        end
        // Byte-wise Write
        else if (|wren_i) begin
                if (offset_i[4:3] == 2'b00)
                        be[7:0] = wren_i;
                else if (offset_i[4:3] == 2'b01)
                        be[15:8] = wren_i;
                else if (offset_i[4:3] == 2'b10)
                        be[23:16] = wren_i;
                else if (offset_i[4:3] == 2'b11)
                        be[31:24] = wren_i;
                we = 1'b1;
                wdata = {4{wdata_i[63:0]}};
        end
end

integer i;
always @(posedge clk_i) begin
        if (we) begin
                for (i = 0; i < 32; i = i+1) begin
                        if (be[i])
                                mem[index_i][i * 8 +: 8] <= wdata[i * 8 +: 8];
                end
        end
end

endmodule

