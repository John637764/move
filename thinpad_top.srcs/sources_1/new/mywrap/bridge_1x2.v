//*************************************************************************
//   > File Name   : bridge_1x2.v
//   > Description : bridge between cpu_data and data ram, confreg
//   
//     master:    cpu_data
//                   |  \
//     1 x 2         |   \  
//     bridge:       |    \                    
//                   |     \       
//     slave:   data_ram  confreg
//
//   > Author      : John
//   > Date        : 2022-07-17
//*************************************************************************
`define CONF_ADDR_BASE 32'hbfd0_03f8
`define CONF_ADDR_MASK 32'hffff_fffb //for bfd0_03f8 or bfd0_03fc
`define RAM_ADDR_BASE  32'h8000_0000 
`define RAM_ADDR_MASK  32'hff80_0000 //for 8000_0000 ~ 807f_ffff
module bridge_1x2(                                 
    input  wire clk,          // clock 
    input  wire reset,        // reset, active high
    // master : cpu data
	input  wire         i_rd_req 	  ,   //读请求有效信号，高电平有效
	input  wire [  2:0] i_rd_type	  ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	input  wire [ 31:0] i_rd_addr	  ,   //读请求起始地址
	output wire         i_rd_rdy 	  ,   //读请求能否被接收的握手信号，高电平有效
	output wire         i_ret_valid   ,   //返回数据有效信号，高电平有效
	output wire  	    i_ret_last    ,   //返回数据是1次读请求对应的最后1个返回数据
	output wire [ 31:0] i_ret_data    ,   //读返回数据
	output wire		    i_wr_rdy      ,
	
	output wire         b_i_rd_req    ,   //读请求有效信号，高电平有效
	output wire [  2:0] b_i_rd_type   ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	output wire [ 31:0] b_i_rd_addr   ,   //读请求起始地址
	input  wire         b_i_rd_rdy    ,   //读请求能否被接收的握手信号，高电平有效
	input  wire         b_i_ret_valid ,   //返回数据有效信号，高电平有效
	input  wire  	    b_i_ret_last  ,   //返回数据是1次读请求对应的最后1个返回数据
	input  wire [ 31:0] b_i_ret_data  ,   //读返回数据
	input  wire		    b_i_wr_rdy    ,	
	
	input  wire         d_rd_req 	  ,   //读请求有效信号，高电平有效
	input  wire [  2:0] d_rd_type	  ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	input  wire [ 31:0] d_rd_addr	  ,   //读请求起始地址
	output wire         d_rd_rdy 	  ,   //读请求能否被接收的握手信号，高电平有效
	output wire         d_ret_valid   ,   //返回数据有效信号，高电平有效
	output wire 	    d_ret_last    ,   //返回数据是1次读请求对应的最后1个返回数据
	output wire [ 31:0] d_ret_data    ,   //读返回数据	
	
	output wire         b_d_rd_req    ,   //读请求有效信号，高电平有效
	output wire [  2:0] b_d_rd_type   ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	output wire [ 31:0] b_d_rd_addr   ,   //读请求起始地址
	input  wire         b_d_rd_rdy    ,   //读请求能否被接收的握手信号，高电平有效
	input  wire         b_d_ret_valid ,   //返回数据有效信号，高电平有效
	input  wire 	    b_d_ret_last  ,   //返回数据是1次读请求对应的最后1个返回数据
	input  wire [ 31:0] b_d_ret_data  ,   //读返回数据	
	
	input  wire         d_wr_req      ,   //写请求有效信号，高电平有效
	input  wire [  2:0] d_wr_type     ,   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	input  wire [ 31:0] d_wr_addr     ,   //写请求起始地址
	input  wire [  3:0] d_wr_wstrb    ,   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
	input  wire [127:0] d_wr_data     ,   //写数据
	output wire         d_wr_rdy      ,   //写请求能否被接收的握手信号，高电平有效
	output wire         d_wr_wvalid   ,   //uncached的写请求响应
	output wire         d_wr_wlast    ,   //uncached的写请求响应

	output wire         b_d_wr_req    ,   //写请求有效信号，高电平有效
	output wire [  2:0] b_d_wr_type   ,   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	output wire [ 31:0] b_d_wr_addr   ,   //写请求起始地址
	output wire [  3:0] b_d_wr_wstrb  ,   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
	output wire [127:0] b_d_wr_data   ,   //写数据
	input  wire         b_d_wr_rdy    ,   //写请求能否被接收的握手信号，高电平有效
	output wire         b_d_wr_wvalid ,   //uncached的写请求响应
	output wire         b_d_wr_wlast  ,   //uncached的写请求响应

    output wire        conf_en,          // access confreg enable 
    output wire [ 3:0] conf_wen,         // access confreg enable 
    output wire [31:0] conf_addr,        // address
    output wire [31:0] conf_wdata,       // write data
    input  wire [31:0] conf_rdata        // read data
);

assign b_i_rd_req  = i_rd_req 	  ;
assign b_i_rd_type = i_rd_type	  ;
assign b_i_rd_addr = i_rd_addr	  ;
assign i_rd_rdy    = b_i_rd_rdy   ;
assign i_ret_valid = b_i_ret_valid;
assign i_ret_last  = b_i_ret_last ;
assign i_ret_data  = b_i_ret_data ;
assign i_wr_rdy    = b_i_wr_rdy   ;

wire sel_sram  ;  // cpu data is from ram
wire sel_conf  ;  // cpu data is from confreg
reg  sel_sram_r;  // reg of sel_dram 
reg  sel_conf_r;  // reg of sel_conf 

assign sel_conf  = (d_rd_addr&`CONF_ADDR_MASK) == `CONF_ADDR_BASE || 
				   (d_wr_addr&`CONF_ADDR_MASK) == `CONF_ADDR_BASE;
assign sel_sram  = !sel_conf;

assign b_d_rd_req  = d_rd_req & sel_sram;
assign b_d_rd_type = d_rd_type;
assign b_d_rd_addr = d_rd_addr;
assign d_rd_rdy    = sel_sram&b_d_rd_rdy | sel_conf;
assign d_ret_valid = sel_sram_r&b_d_ret_valid | sel_conf_r;
assign d_ret_last  = sel_sram_r&b_d_ret_last  | sel_conf_r;
assign d_ret_data  = {32{sel_sram_r}} & b_d_ret_data | {32{sel_conf_r}} & conf_rdata;

assign d_wr_rdy    = sel_sram&b_d_wr_rdy | sel_conf;
assign d_wr_wvalid = sel_conf_r | b_d_wr_wvalid;
assign d_wr_wlast  = sel_conf_r | b_d_wr_wlast;
assign b_d_wr_req  = sel_sram&d_wr_req;
assign b_d_wr_type = d_wr_type    ;
assign b_d_wr_addr = d_wr_addr    ;
assign b_d_wr_wstrb= d_wr_wstrb   ;
assign b_d_wr_data = d_wr_data    ;

// confreg
assign conf_en    = (d_rd_req | d_wr_req) & sel_conf;
assign conf_wen   = {4{d_wr_req & sel_conf}} & 4'hf;
assign conf_addr  = d_wr_req ? d_wr_addr : d_rd_addr;
assign conf_wdata = d_wr_data;

always @(posedge clk)
begin
    if (reset)
    begin
        sel_sram_r <= 1'b0;
        sel_conf_r <= 1'b0;
    end
    else
    begin
        sel_sram_r <= sel_sram;
        sel_conf_r <= sel_conf;
    end
end



endmodule

