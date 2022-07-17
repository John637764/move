module sram_wrap(
	input  wire clk  ,
	input  wire reset,
	//receive from cpu
	input  wire        en   ,
	input  wire [ 3:0] wen  ,
	input  wire [31:0] addr ,
	input  wire [31:0] wdata,
	output reg  [31:0] rdata,
	//send to board
	inout  wire [31:0] sram_data,
	output wire [19:0] sram_addr, 
    output wire [ 3:0] sram_be_n, 
	output wire        sram_ce_n,
	output wire        sram_oe_n,
	output wire        sram_we_n
);

reg [31:0] addr_r;
always @(posedge clk)begin
	if(reset)
		addr_r <= 32'hffff_ffff;
	else if(en)
		addr_r <= addr;
end
always @(posedge clk)begin
	if(|addr_r^addr_r)
		rdata <= sram_data;
end

assign sram_data = |wen&&en ? wdata : 32'bz;
assign sram_addr = addr[21:2];
assign sram_be_n = ~(|wen&&en ? wen : 4'hf);
assign sram_ce_n = ~en;
assign sram_oe_n = ~(~(|wen)&&en);
assign sram_we_n = ~(|wen&&en);

endmodule