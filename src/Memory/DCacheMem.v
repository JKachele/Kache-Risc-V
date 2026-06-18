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

always @(posedge clk_i) begin
        if (rden_i)
                rdata_o <= mem[index_i];
        if (wrall_i) begin
                mem[index_i] <= wdata_i;
        end else if (offset_i[4:3] == 2'b00) begin
                if (wren_i[0]) mem[index_i][  7:0  ]   <= wdata_i[ 7:0 ];
                if (wren_i[1]) mem[index_i][ 15:8  ]   <= wdata_i[15:8 ];
                if (wren_i[2]) mem[index_i][ 23:16 ]   <= wdata_i[23:16];
                if (wren_i[3]) mem[index_i][ 31:24 ]   <= wdata_i[31:24];
                if (wren_i[4]) mem[index_i][ 39:32 ]   <= wdata_i[39:32];
                if (wren_i[5]) mem[index_i][ 47:40 ]   <= wdata_i[47:40];
                if (wren_i[6]) mem[index_i][ 55:48 ]   <= wdata_i[55:48];
                if (wren_i[7]) mem[index_i][ 63:56 ]   <= wdata_i[63:56];
        end else if (offset_i[4:3] == 2'b01) begin
                if (wren_i[0]) mem[index_i][ 71:64 ]   <= wdata_i[ 7:0 ];
                if (wren_i[1]) mem[index_i][ 79:72 ]   <= wdata_i[15:8 ];
                if (wren_i[2]) mem[index_i][ 87:80 ]   <= wdata_i[23:16];
                if (wren_i[3]) mem[index_i][ 95:88 ]   <= wdata_i[31:24];
                if (wren_i[4]) mem[index_i][103:96 ]   <= wdata_i[39:32];
                if (wren_i[5]) mem[index_i][111:104]   <= wdata_i[47:40];
                if (wren_i[6]) mem[index_i][119:112]   <= wdata_i[55:48];
                if (wren_i[7]) mem[index_i][127:120]   <= wdata_i[63:56];
        end else if (offset_i[4:3] == 2'b10) begin
                if (wren_i[0]) mem[index_i][135:128]   <= wdata_i[ 7:0 ];
                if (wren_i[1]) mem[index_i][143:136]   <= wdata_i[15:8 ];
                if (wren_i[2]) mem[index_i][151:144]   <= wdata_i[23:16];
                if (wren_i[3]) mem[index_i][159:152]   <= wdata_i[31:24];
                if (wren_i[4]) mem[index_i][167:160]   <= wdata_i[39:32];
                if (wren_i[5]) mem[index_i][175:168]   <= wdata_i[47:40];
                if (wren_i[6]) mem[index_i][183:176]   <= wdata_i[55:48];
                if (wren_i[7]) mem[index_i][191:184]   <= wdata_i[63:56];
        end else if (offset_i[4:3] == 2'b11) begin
                if (wren_i[0]) mem[index_i][199:192]   <= wdata_i[ 7:0 ];
                if (wren_i[1]) mem[index_i][207:200]   <= wdata_i[15:8 ];
                if (wren_i[2]) mem[index_i][215:208]   <= wdata_i[23:16];
                if (wren_i[3]) mem[index_i][223:216]   <= wdata_i[31:24];
                if (wren_i[4]) mem[index_i][231:224]   <= wdata_i[39:32];
                if (wren_i[5]) mem[index_i][239:232]   <= wdata_i[47:40];
                if (wren_i[6]) mem[index_i][247:240]   <= wdata_i[55:48];
                if (wren_i[7]) mem[index_i][255:248]   <= wdata_i[63:56];
        end
end

endmodule

