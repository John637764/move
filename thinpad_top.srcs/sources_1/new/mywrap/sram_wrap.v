module sram_wrap(
	input  wire clk  ,
	input  wire reset,
	//receive from cpu
	input  wire        en   ,
	input  wire [ 3:0] wen  ,
	input  wire [31:0] addr ,
	input  wire [31:0] wdata,
	output wire [31:0] rdata,
	//send to board
	inout  wire [31:0] sram_data,
	output reg  [19:0] sram_addr, 
    output reg  [ 3:0] sram_be_n, 
	output reg         sram_ce_n,
	output reg         sram_oe_n,
	output reg         sram_we_n
);

assign sram_data = |wen&&en ? wdata : 32'bz;
assign rdata = sram_data;
//always @(posedge clk)begin
//	rdata <= sram_data;
//end
always @(posedge clk)begin
	sram_addr <= addr[21:2];
end
always @(posedge clk)begin
	sram_be_n <= ~(|wen&&en ? wen : 4'hf);
end
always @(posedge clk)begin
	sram_ce_n <= ~en;
end
always @(posedge clk)begin
	sram_oe_n <= ~(~(|wen)&&en);
end
always @(posedge clk)begin
	sram_we_n <= ~(|wen&&en);
end

endmodule