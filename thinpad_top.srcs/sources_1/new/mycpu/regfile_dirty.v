module regfile_dirty #(parameter GROUP_NUM = 256)
(
	input  wire clk  ,
	input  wire reset,
	input  wire wen  ,
	input  wire [$clog2(GROUP_NUM)-1:0] addr,
	input  wire din  ,
	output wire dout
);

reg [GROUP_NUM-1:0] Dirtybity;

always @(posedge clk) begin
	if(reset)
		Dirtybity <= 256'b0;
	else if(wen)
		Dirtybity[addr] <= din;
end

assign dout = Dirtybity[addr];
endmodule