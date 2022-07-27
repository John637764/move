`define BASE_RAM_ADDR 32'h8000_0000
`define BASE_RAM_MASK 32'hFFC0_0000
`define EXT_RAM_ADDR  32'h8040_0000
`define EXT_RAM_MASK  32'hFFC0_0000

module sram_interface (
    input  wire clk  ,   
    input  wire reset,   
	//icache与SRAM交互的接口
    input  wire         i_rd_req 	,   //读请求有效信号，高电平有效
    input  wire [  2:0] i_rd_type	,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    input  wire [ 31:0] i_rd_addr	,   //读请求起始地址
    output wire         i_rd_rdy 	,   //读请求能否被接收的握手信号，高电平有效
    output wire         i_ret_valid ,   //返回数据有效信号，高电平有效
    output wire  	    i_ret_last  ,   //返回数据是1次读请求对应的最后1个返回数据
    output wire [ 31:0] i_ret_data  ,   //读返回数据                        
    output wire         i_wr_rdy    ,   //写请求能否被接收的握手信号，高电平有效
	//dcache与SRAM交互的接口
	input  wire         d_rd_req 	,   //读请求有效信号，高电平有效
    input  wire [  2:0] d_rd_type	,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    input  wire [ 31:0] d_rd_addr	,   //读请求起始地址
    output wire         d_rd_rdy 	,   //读请求能否被接收的握手信号，高电平有效
    output wire         d_ret_valid ,   //返回数据有效信号，高电平有效
    output wire 	    d_ret_last  ,   //返回数据是1次读请求对应的最后1个返回数据
    output wire [ 31:0] d_ret_data  ,   //读返回数据                        
    
	input  wire         d_wr_req    ,   //写请求有效信号，高电平有效
    input  wire [  2:0] d_wr_type   ,   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    input  wire [ 31:0] d_wr_addr   ,   //写请求起始地址
    input  wire [  3:0] d_wr_wstrb  ,   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    input  wire [127:0] d_wr_data   ,   //写数据
    output wire         d_wr_rdy    ,   //写请求能否被接收的握手信号，高电平有效
//	output wire         d_wr_wvalid ,
//	output wire         d_wr_wlast  ,
    //sram 接口
	//BaseRAM信号
 	input  wire  [31:0] base_ram_rdata,  //BaseRAM读入数据
 	output reg   [31:0] base_ram_wdata,	 //BaseRAM写出数据
	output reg   [19:0] base_ram_addr ,  //BaseRAM地址
 	output reg   [ 3:0] base_ram_be_n ,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
 	output reg    	    base_ram_ce_n ,  //BaseRAM片选，低有效
 	output reg    	    base_ram_oe_n ,  //BaseRAM读使能，低有效
 	output reg    	    base_ram_we_n ,  //BaseRAM写使能，低有效
    //ExtRAM信号 
    input  wire  [31:0] ext_ram_rdata ,   //ExtRAM读入数据
    output reg   [31:0] ext_ram_wdata ,	  //ExtRAM写出数据
	output reg   [19:0] ext_ram_addr  ,   //ExtRAM地址
    output reg   [ 3:0] ext_ram_be_n  ,   //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output reg    	    ext_ram_ce_n  ,   //ExtRAM片选，低有效
    output reg    	    ext_ram_oe_n  ,   //ExtRAM读使能，低有效
    output reg    	    ext_ram_we_n      //ExtRAM写使能，低有效
);
wire         d_wr_wvalid ;
wire         d_wr_wlast  ;
reg [2:0] ib_rd_cnt;	//icache读base ram计数器
reg [2:0] db_rd_cnt;	//dcache读base ram计数器
reg [2:0] db_wr_cnt;	//dcache写base ram计数器
reg [2:0] de_rd_cnt;	//dcache读ext  ram计数器
reg [2:0] de_wr_cnt;	//dcache写ext  ram计数器

always @(posedge clk)begin
	if(reset)
		ib_rd_cnt <= 3'd0;
	else if(i_rd_req && (i_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)begin
		case(i_rd_type)
			3'b010 : ib_rd_cnt <= 3'd1;
			3'b100 : ib_rd_cnt <= 3'd4;
			default: ib_rd_cnt <= 3'd0;
		endcase
	end
	else if(ib_rd_cnt && !(db_rd_cnt > 3'd1 || db_wr_cnt > 3'd1                      ||
						   d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR  ||
						   d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR) &&
						 !(ib_rd_cnt == 3'd1 && (de_rd_cnt > 3'd1 || de_wr_cnt > 3'd1)))
		ib_rd_cnt <= ib_rd_cnt - 1;
end

reg 	   inst_last_buf_v;
reg [31:0] inst_last_buf  ;
always @(posedge clk)begin
	if(ib_rd_cnt == 3'd1 && (de_rd_cnt > 3'd1 || de_wr_cnt > 3'd1) && !inst_last_buf_v)
		inst_last_buf <= base_ram_rdata;
end
always @(posedge clk)begin
	if(reset)
		inst_last_buf_v <= 1'b0;
	else if(ib_rd_cnt == 3'd1 && (de_rd_cnt > 3'd1 || de_wr_cnt > 3'd1))
		inst_last_buf_v <= 1'b1;
	else if(inst_last_buf_v && i_ret_last)
		inst_last_buf_v <= 1'b0;
end

assign i_rd_rdy    = !ib_rd_cnt && !(db_rd_cnt && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR || 
									 db_wr_cnt && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR);
assign i_ret_valid = |ib_rd_cnt && !(db_rd_cnt || db_wr_cnt) && !(ib_rd_cnt == 3'd1 && 
																 (de_rd_cnt > 3'd1 || de_wr_cnt > 3'd1));
assign i_ret_last  = ib_rd_cnt == 3'd1 && !(de_rd_cnt > 3'd1 || de_wr_cnt > 3'd1);
assign i_ret_data  = inst_last_buf_v ? inst_last_buf : base_ram_rdata;
assign i_wr_rdy    = 1'b1;

always @(posedge clk)begin
	if(reset)
		db_rd_cnt <= 3'd0;
	else if(d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)begin
		case(d_rd_type)
			3'b010 : db_rd_cnt <= 3'd1;
		    3'b100 : db_rd_cnt <= 3'd4;
		    default: db_rd_cnt <= 3'd0;
		endcase
	end
	else if(db_rd_cnt)
		db_rd_cnt <= db_rd_cnt - 1;
end

always @(posedge clk)begin
	if(reset)
		db_wr_cnt <= 3'd0;
	else if(d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)begin
		case(d_wr_type)
			3'b010 : db_wr_cnt <= 3'd1;
		    3'b100 : db_wr_cnt <= 3'd4;
		    default: db_wr_cnt <= 3'd0;
		endcase
	end
	else if(db_wr_cnt)
		db_wr_cnt <= db_wr_cnt - 1;
end

always @(posedge clk)begin
	if(reset)
		de_rd_cnt <= 3'd0;
	else if(d_rd_req && (d_rd_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR)begin
		case(d_rd_type)
			3'b010 : de_rd_cnt <= 3'd1;
		    3'b100 : de_rd_cnt <= 3'd4;
		    default: de_rd_cnt <= 3'd0;		
		endcase
	end
	else if(de_rd_cnt)
		de_rd_cnt <= de_rd_cnt - 1;
end

always @(posedge clk)begin
	if(reset)
		de_wr_cnt <= 3'd0;
	else if(d_wr_req && (d_wr_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR)begin
		case(d_wr_type)
			3'b010 : de_wr_cnt <= 3'd1;
		    3'b100 : de_wr_cnt <= 3'd4;
		    default: de_wr_cnt <= 3'd0;				
		endcase	
	end
	else if(de_wr_cnt)
		de_wr_cnt <= de_wr_cnt - 1;
end

assign d_rd_rdy    = !db_rd_cnt && !db_wr_cnt;
assign d_ret_valid = |db_rd_cnt || |de_rd_cnt;
assign d_ret_last  = db_rd_cnt == 3'd1 || de_rd_cnt == 3'd1;
assign d_ret_data  = db_rd_cnt ? base_ram_rdata : ext_ram_rdata;

assign d_wr_rdy    = !db_wr_cnt && !de_wr_cnt;

assign d_wr_wvalid = |db_wr_cnt || |de_wr_cnt;
assign d_wr_wlast  = db_wr_cnt == 3'd1 || de_wr_cnt == 3'd1;

reg [95:0] w_buf;
reg [19:0] i_addr_buf;
reg 	   i_addr_buf_v;
always @(posedge clk)begin
	if(reset)
		i_addr_buf_v <= 1'b0;
	else if(ib_rd_cnt && (d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR || 
					 d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR))
		i_addr_buf_v <= 1'b1;
	else if(i_addr_buf_v && (i_addr_buf_v && d_ret_last))
		i_addr_buf_v <= 1'b0;
end
always @(posedge clk)begin
	if(ib_rd_cnt && (d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR || 
					 d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR))
		i_addr_buf <= base_ram_addr + 1;
end
always @(posedge clk)begin
	if(d_wr_req)
		w_buf <= d_wr_data[127:32];
	else
		w_buf <= w_buf >> 32;
end
always @(posedge clk)begin
	if(!db_wr_cnt)
		base_ram_wdata <= d_wr_data[31:0];
	else
		base_ram_wdata <= w_buf[31:0];
end
always @(posedge clk)begin
	if(d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)
		base_ram_addr <= d_wr_addr[21:2];
	else if(d_rd_req && !db_wr_cnt && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)
		base_ram_addr <= d_rd_addr[21:2];
	else if(i_rd_req && !db_wr_cnt && !db_rd_cnt && (i_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR)
		base_ram_addr <= i_rd_addr[21:2];
	else if(i_addr_buf_v && d_ret_last)
		base_ram_addr <= i_addr_buf;
	else
		base_ram_addr <= base_ram_addr + 1;
end
always @(posedge clk)begin
	if(reset)
		base_ram_be_n <= 4'hf;
	else
		base_ram_be_n <= 4'h0;
end
always @(posedge clk)begin
	if(reset)
		base_ram_ce_n <= 1'b1;
	else
		base_ram_ce_n <= ~(d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR || 
						   d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR ||
						   i_rd_req && (i_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR ||
						   ib_rd_cnt && !i_ret_last || db_rd_cnt && !d_ret_last || db_wr_cnt && !d_wr_wlast);
end
always @(posedge clk)begin
	if(reset)
		base_ram_oe_n <= 1'b1;
	else
		base_ram_oe_n <= ~(d_rd_req && (d_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR ||
						   i_rd_req && (i_rd_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR ||
						   ib_rd_cnt && !i_ret_last || db_rd_cnt && !d_ret_last);
end
always @(posedge clk)begin
	if(reset)
		base_ram_we_n <= 1'b1;
	else
		base_ram_we_n <= ~(d_wr_req && (d_wr_addr&`BASE_RAM_MASK) == `BASE_RAM_ADDR || db_wr_cnt && !d_wr_wlast);
end

always @(posedge clk)begin
	if(!de_wr_cnt)
		ext_ram_wdata <= d_wr_data[31:0];
	else
		ext_ram_wdata <= w_buf[31:0];
end
always @(posedge clk)begin
	if(d_wr_req && (d_wr_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR)
		ext_ram_addr <= d_wr_addr[21:2];
	else if(d_rd_req && (d_rd_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR)
		ext_ram_addr <= d_rd_addr[21:2];
	else
		ext_ram_addr <= ext_ram_addr + 1;
end
always @(posedge clk)begin
	if(reset)
		ext_ram_be_n <= 4'hf;
	else
		ext_ram_be_n <= 4'h0;
end
always @(posedge clk)begin
	if(reset)
		ext_ram_ce_n <= 1'b1;
	else
		ext_ram_ce_n <= ~(d_wr_req && (d_wr_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR ||
						  d_rd_req && (d_rd_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR || 
						  de_wr_cnt && !d_wr_wlast || de_rd_cnt && !d_ret_last);
end
always @(posedge clk)begin
	if(reset)
		ext_ram_oe_n <= 1'b1;
	else
		ext_ram_oe_n <= ~(d_rd_req && (d_rd_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR || de_rd_cnt && !d_ret_last);
end
always @(posedge clk)begin
	if(reset)
		ext_ram_we_n <= 1'b1;
	else
		ext_ram_we_n <= ~(d_wr_req && (d_wr_addr&`EXT_RAM_MASK) == `EXT_RAM_ADDR || de_wr_cnt && !d_wr_wlast);
end

endmodule //sram_interface