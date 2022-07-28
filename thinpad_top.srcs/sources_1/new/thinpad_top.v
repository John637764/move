`default_nettype none

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    //BaseRAM信号
    inout  wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr,  //BaseRAM地址
    output wire[ 3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire 	  base_ram_ce_n,  //BaseRAM片选，低有效
    output wire 	  base_ram_oe_n,  //BaseRAM读使能，低有效
    output wire 	  base_ram_we_n,  //BaseRAM写使能，低有效

    //ExtRAM信号
    inout  wire[31:0] ext_ram_data,   //ExtRAM数据
    output wire[19:0] ext_ram_addr,   //ExtRAM地址
    output wire[ 3:0] ext_ram_be_n,   //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire 	  ext_ram_ce_n,   //ExtRAM片选，低有效
    output wire 	  ext_ram_oe_n,   //ExtRAM读使能，低有效
    output wire 	  ext_ram_we_n,   //ExtRAM写使能，低有效

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd   //直连串口接收端
);

wire [31:0] base_ram_wdata;
wire [31:0] ext_ram_wdata;

/* =========== Demo code begin =========== */

// PLL分频示例
wire locked, cpu_clk, slave_clk;
pll_example clock_gen(
	// Clock in ports
	.clk_in1(clk_50M),  // 外部时钟输入
	// Clock out ports
	.clk_out1(cpu_clk), // 时钟输出1，频率在IP配置界面中设置
	.clk_out2(slave_clk), // 时钟输出2，频率在IP配置界面中设置
	// Status and control signals
	.reset(reset_btn), // PLL复位输入
	.locked(locked)    // PLL锁定指示输出，"1"表示时钟稳定，
						// 后级电路复位信号应当由它生成（见下）
);

reg cpu_reset;
// 异步复位,将locked信号转为后级电路的复位reset_of_clk10M
always@(posedge cpu_clk) begin
	cpu_reset <= ~locked;
end

wire         i_rd_req 	   ;   //读请求有效信号，高电平有效
wire [  2:0] i_rd_type	   ;   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] i_rd_addr	   ;   //读请求起始地址
wire         i_rd_rdy 	   ;   //读请求能否被接收的握手信号，高电平有效
wire         i_ret_valid   ;   //返回数据有效信号，高电平有效
wire  	     i_ret_last    ;   //返回数据是1次读请求对应的最后1个返回数据
wire [ 31:0] i_ret_data    ;   //读返回数据
wire		 i_wr_rdy      ;

wire         b_i_rd_req    ;   //读请求有效信号，高电平有效
wire [  2:0] b_i_rd_type   ;   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] b_i_rd_addr   ;   //读请求起始地址
wire         b_i_rd_rdy    ;   //读请求能否被接收的握手信号，高电平有效
wire         b_i_ret_valid ;   //返回数据有效信号，高电平有效
wire  	     b_i_ret_last  ;   //返回数据是1次读请求对应的最后1个返回数据
wire [ 31:0] b_i_ret_data  ;   //读返回数据
wire		 b_i_wr_rdy    ;

wire         d_rd_req 	   ;   //读请求有效信号，高电平有效
wire [  2:0] d_rd_type	   ;   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] d_rd_addr	   ;   //读请求起始地址
wire         d_rd_rdy 	   ;   //读请求能否被接收的握手信号，高电平有效
wire         d_ret_valid   ;   //返回数据有效信号，高电平有效
wire 	     d_ret_last    ;   //返回数据是1次读请求对应的最后1个返回数据
wire [ 31:0] d_ret_data    ;   //读返回数据

wire         b_d_rd_req    ;   //读请求有效信号，高电平有效
wire [  2:0] b_d_rd_type   ;   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] b_d_rd_addr   ;   //读请求起始地址
wire         b_d_rd_rdy    ;   //读请求能否被接收的握手信号，高电平有效
wire         b_d_ret_valid ;   //返回数据有效信号，高电平有效
wire 	     b_d_ret_last  ;   //返回数据是1次读请求对应的最后1个返回数据
wire [ 31:0] b_d_ret_data  ;   //读返回数据

wire         d_wr_req      ;   //写请求有效信号，高电平有效
wire [  2:0] d_wr_type     ;   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] d_wr_addr     ;   //写请求起始地址
wire [  3:0] d_wr_wstrb    ;   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
wire [127:0] d_wr_data     ;   //写数据
wire         d_wr_rdy      ;   //写请求能否被接收的握手信号，高电平有效
wire         d_wr_wvalid   ;   //uncached的写请求响应
wire         d_wr_wlast    ;   //uncached的写请求响应
                           
wire         b_d_wr_req    ;   //写请求有效信号，高电平有效
wire [  2:0] b_d_wr_type   ;   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
wire [ 31:0] b_d_wr_addr   ;   //写请求起始地址
wire [  3:0] b_d_wr_wstrb  ;   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
wire [127:0] b_d_wr_data   ;   //写数据
wire         b_d_wr_rdy    ;   //写请求能否被接收的握手信号，高电平有效
wire         b_d_wr_wvalid ;   //uncached的写请求响应
wire         b_d_wr_wlast  ;   //uncached的写请求响应

wire         conf_en   ;       
wire [  3:0] conf_wen  ;       
wire [ 31:0] conf_addr ;       
wire [ 31:0] conf_wdata;       
wire [ 31:0] conf_rdata;      
//cpu
mycpu_top u_cpu(
    .clk          (cpu_clk   ),
    .reset        (cpu_reset ),  //low active

    .i_rd_req 	  (i_rd_req 	),   //读请求有效信号，高电平有效
    .i_rd_type	  (i_rd_type	),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .i_rd_addr	  (i_rd_addr	),   //读请求起始地址
    .i_rd_rdy 	  (i_rd_rdy 	),   //读请求能否被接收的握手信号，高电平有效
    .i_ret_valid  (i_ret_valid  ),   //返回数据有效信号，高电平有效
    .i_ret_last   (i_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
    .i_ret_data   (i_ret_data   ),   //读返回数据
	.i_wr_rdy     (i_wr_rdy     ),
	
    .d_rd_req 	  (d_rd_req 	),   //读请求有效信号，高电平有效
    .d_rd_type	  (d_rd_type	),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .d_rd_addr	  (d_rd_addr	),   //读请求起始地址
    .d_rd_rdy 	  (d_rd_rdy 	),   //读请求能否被接收的握手信号，高电平有效
    .d_ret_valid  (d_ret_valid  ),   //返回数据有效信号，高电平有效
    .d_ret_last   (d_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
    .d_ret_data   (d_ret_data   ),   //读返回数据

    .d_wr_req     (d_wr_req     ),   //写请求有效信号，高电平有效
    .d_wr_type    (d_wr_type    ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .d_wr_addr    (d_wr_addr    ),   //写请求起始地址
    .d_wr_wstrb   (d_wr_wstrb   ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    .d_wr_data    (d_wr_data    ),   //写数据
    .d_wr_rdy     (d_wr_rdy     ),   //写请求能否被接收的握手信号，高电平有效
	.d_wr_wvalid  (d_wr_wvalid  ),   //uncached的写请求响应
	.d_wr_wlast   (d_wr_wlast   ),   //uncached的写请求响应

    //debug
    .debug_wb_pc      (),
    .debug_wb_rf_wen  (),
    .debug_wb_rf_wnum (),
    .debug_wb_rf_wdata()
);

bridge_1x2 u_bridge(                                 
    .clk           (slave_clk),          // clock 
    .reset         (cpu_reset),        // reset, active high
    // master : cpu data
	.i_rd_req 	   (i_rd_req 	 ),   //读请求有效信号，高电平有效
	.i_rd_type	   (i_rd_type	 ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.i_rd_addr	   (i_rd_addr	 ),   //读请求起始地址
	.i_rd_rdy 	   (i_rd_rdy 	 ),   //读请求能否被接收的握手信号，高电平有效
	.i_ret_valid   (i_ret_valid  ),   //返回数据有效信号，高电平有效
	.i_ret_last    (i_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
	.i_ret_data    (i_ret_data   ),   //读返回数据
	.i_wr_rdy      (i_wr_rdy     ),
	
	.b_i_rd_req    (b_i_rd_req   ),   //读请求有效信号，高电平有效
	.b_i_rd_type   (b_i_rd_type  ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.b_i_rd_addr   (b_i_rd_addr  ),   //读请求起始地址
	.b_i_rd_rdy    (b_i_rd_rdy   ),   //读请求能否被接收的握手信号，高电平有效
	.b_i_ret_valid (b_i_ret_valid),   //返回数据有效信号，高电平有效
	.b_i_ret_last  (b_i_ret_last ),   //返回数据是1次读请求对应的最后1个返回数据
	.b_i_ret_data  (b_i_ret_data ),   //读返回数据
	.b_i_wr_rdy    (b_i_wr_rdy   ),	
	
	.d_rd_req 	   (d_rd_req 	 ),   //读请求有效信号，高电平有效
	.d_rd_type	   (d_rd_type	 ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.d_rd_addr	   (d_rd_addr	 ),   //读请求起始地址
	.d_rd_rdy 	   (d_rd_rdy 	 ),   //读请求能否被接收的握手信号，高电平有效
	.d_ret_valid   (d_ret_valid  ),   //返回数据有效信号，高电平有效
	.d_ret_last    (d_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
	.d_ret_data    (d_ret_data   ),   //读返回数据	
	
	.b_d_rd_req    (b_d_rd_req   ),   //读请求有效信号，高电平有效
	.b_d_rd_type   (b_d_rd_type  ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.b_d_rd_addr   (b_d_rd_addr  ),   //读请求起始地址
	.b_d_rd_rdy    (b_d_rd_rdy   ),   //读请求能否被接收的握手信号，高电平有效
	.b_d_ret_valid (b_d_ret_valid),   //返回数据有效信号，高电平有效
	.b_d_ret_last  (b_d_ret_last ),   //返回数据是1次读请求对应的最后1个返回数据
	.b_d_ret_data  (b_d_ret_data ),   //读返回数据	
	
	.d_wr_req      (d_wr_req     ),   //写请求有效信号，高电平有效
	.d_wr_type     (d_wr_type    ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.d_wr_addr     (d_wr_addr    ),   //写请求起始地址
	.d_wr_wstrb    (d_wr_wstrb   ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
	.d_wr_data     (d_wr_data    ),   //写数据
	.d_wr_rdy      (d_wr_rdy     ),   //写请求能否被接收的握手信号，高电平有效
	.d_wr_wvalid   (d_wr_wvalid  ),   //uncached的写请求响应
	.d_wr_wlast    (d_wr_wlast   ),   //uncached的写请求响应

	.b_d_wr_req    (b_d_wr_req   ),   //写请求有效信号，高电平有效
	.b_d_wr_type   (b_d_wr_type  ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
	.b_d_wr_addr   (b_d_wr_addr  ),   //写请求起始地址
	.b_d_wr_wstrb  (b_d_wr_wstrb ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
	.b_d_wr_data   (b_d_wr_data  ),   //写数据
	.b_d_wr_rdy    (b_d_wr_rdy   ),   //写请求能否被接收的握手信号，高电平有效
	.b_d_wr_wvalid (b_d_wr_wvalid),
	.b_d_wr_wlast  (b_d_wr_wlast ),

    .conf_en       (conf_en      ),   // access confreg enable 
    .conf_wen      (conf_wen     ),   // access confreg enable 
    .conf_addr     (conf_addr    ),   // address
    .conf_wdata    (conf_wdata   ),   // write data
    .conf_rdata    (conf_rdata   )    // read data
);

sram_interface u_sram(
    .clk   (slave_clk),   
    .reset (cpu_reset),   
	//icache与SRAM交互的接口
    .i_rd_req 	 (b_i_rd_req 	 ),   //读请求有效信号，高电平有效
    .i_rd_type	 (b_i_rd_type	 ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .i_rd_addr	 (b_i_rd_addr	 ),   //读请求起始地址
    .i_rd_rdy 	 (b_i_rd_rdy 	 ),   //读请求能否被接收的握手信号，高电平有效
    .i_ret_valid (b_i_ret_valid  ),   //返回数据有效信号，高电平有效
    .i_ret_last  (b_i_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
    .i_ret_data  (b_i_ret_data   ),   //读返回数据                        
    .i_wr_rdy    (b_i_wr_rdy     ),   //写请求能否被接收的握手信号，高电平有效
	//dcache与SRAM交互的接口
	.d_rd_req 	 (b_d_rd_req 	 ),   //读请求有效信号，高电平有效
    .d_rd_type	 (b_d_rd_type	 ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .d_rd_addr	 (b_d_rd_addr	 ),   //读请求起始地址
    .d_rd_rdy 	 (b_d_rd_rdy 	 ),   //读请求能否被接收的握手信号，高电平有效
    .d_ret_valid (b_d_ret_valid  ),   //返回数据有效信号，高电平有效
    .d_ret_last  (b_d_ret_last   ),   //返回数据是1次读请求对应的最后1个返回数据
    .d_ret_data  (b_d_ret_data   ),   //读返回数据                        
    
	.d_wr_req    (b_d_wr_req   	 ),   //写请求有效信号，高电平有效
    .d_wr_type   (b_d_wr_type  	 ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .d_wr_addr   (b_d_wr_addr  	 ),   //写请求起始地址
    .d_wr_wstrb  (b_d_wr_wstrb 	 ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    .d_wr_data   (b_d_wr_data  	 ),   //写数据
    .d_wr_rdy    (b_d_wr_rdy   	 ),   //写请求能否被接收的握手信号，高电平有效
	.d_wr_wvalid (b_d_wr_wvalid  ),
	.d_wr_wlast  (b_d_wr_wlast   ),	
    //sram 接口
	//BaseRAM信号
 	.base_ram_rdata (base_ram_data),  //BaseRAM读入数据
 	.base_ram_wdata (base_ram_wdata), //BaseRAM写出数据
	.base_ram_addr  (base_ram_addr),  //BaseRAM地址
 	.base_ram_be_n  (base_ram_be_n),  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
 	.base_ram_ce_n  (base_ram_ce_n),  //BaseRAM片选，低有效
 	.base_ram_oe_n  (base_ram_oe_n),  //BaseRAM读使能，低有效
 	.base_ram_we_n  (base_ram_we_n),  //BaseRAM写使能，低有效
    //ExtRAM信号
    .ext_ram_rdata 	(ext_ram_data ),   //ExtRAM读入数据
    .ext_ram_wdata  (ext_ram_wdata),   //ExtRAM写出数据
	.ext_ram_addr 	(ext_ram_addr ),   //ExtRAM地址
    .ext_ram_be_n 	(ext_ram_be_n ),   //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    .ext_ram_ce_n 	(ext_ram_ce_n ),   //ExtRAM片选，低有效
    .ext_ram_oe_n 	(ext_ram_oe_n ),   //ExtRAM读使能，低有效
    .ext_ram_we_n 	(ext_ram_we_n )    //ExtRAM写使能，低有效
);

assign base_ram_data = ~base_ram_ce_n && ~base_ram_we_n ? base_ram_wdata : 32'bz;
assign ext_ram_data  = ~ext_ram_ce_n  && ~ext_ram_we_n  ? ext_ram_wdata  : 32'bz;

//confreg
confreg u_confreg(                     
    .clk        (slave_clk),
    .reset      (cpu_reset),     
    // read and write from cpu
	.conf_en    (conf_en   ),      
	.conf_wen   (conf_wen  ),      
	.conf_addr  (conf_addr ),    
	.conf_wdata (conf_wdata),   
	.conf_rdata (conf_rdata),   
	.txd 		(txd),  //直连串口发送端
	.rxd 		(rxd)   //直连串口接收端
);

endmodule
