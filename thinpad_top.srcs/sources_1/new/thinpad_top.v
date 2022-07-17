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

/* =========== Demo code begin =========== */

// PLL分频示例
wire locked, clk_20M, clk_10M;
pll_example clock_gen(
	// Clock in ports
	.clk_in1(clk_50M),  // 外部时钟输入
	// Clock out ports
	.clk_out1(clk_20M), // 时钟输出1，频率在IP配置界面中设置
	.clk_out2(clk_10M), // 时钟输出2，频率在IP配置界面中设置
	// Status and control signals
	.reset(reset_btn), // PLL复位输入
	.locked(locked)    // PLL锁定指示输出，"1"表示时钟稳定，
						// 后级电路复位信号应当由它生成（见下）
);


reg cpu_reset;
// 异步复位,将locked信号转为后级电路的复位reset_of_clk10M
always@(posedge clk_20M) begin
	cpu_reset <= ~locked;
end

//cpu inst sram
wire        cpu_inst_en   ;
wire [3 :0] cpu_inst_wen  ;
wire [31:0] cpu_inst_addr ;
wire [31:0] cpu_inst_wdata;
wire [31:0] cpu_inst_rdata;
//cpu data sram
wire        cpu_data_en   ;
wire [3 :0] cpu_data_wen  ;
wire [31:0] cpu_data_addr ;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;
//data sram
//wire        data_sram_en   ;
//wire [3 :0] data_sram_wen  ;
//wire [31:0] data_sram_addr ;
//wire [31:0] data_sram_wdata;
//wire [31:0] data_sram_rdata;
//conf
wire        conf_en   ;
wire [3 :0] conf_wen  ;
wire [31:0] conf_addr ;
wire [31:0] conf_wdata;
wire [31:0] conf_rdata;
//cpu
mycpu_top u_cpu(
    .clk              (clk_20M   ),
    .reset            (cpu_reset ),  //low active

    .inst_sram_en     (cpu_inst_en   ),
    .inst_sram_wen    (cpu_inst_wen  ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
    
    .data_sram_en     (cpu_data_en   ),
    .data_sram_wen    (cpu_data_wen  ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata),

    //debug
    .debug_wb_pc      (),
    .debug_wb_rf_wen  (),
    .debug_wb_rf_wnum (),
    .debug_wb_rf_wdata()
);

//inst_ram inst_ram (
//  .clka  (clk_20M),             // input wire clka
//  .ena   (cpu_inst_en   ),      // input wire ena
//  .wea   (cpu_inst_wen  ),      // input wire [3 : 0] wea
//  .addra (cpu_inst_addr ),      // input wire [17 : 0] addra
//  .dina  (cpu_inst_wdata),      // input wire [31 : 0] dina
//  .douta (cpu_inst_rdata)      // output wire [31 : 0] douta
//);
//
//data_ram data_ram (
//  .clka  (clk_20M),             // input wire clka
//  .ena   (cpu_data_en   ),      // input wire ena
//  .wea   (cpu_data_wen  ),      // input wire [3 : 0] wea
//  .addra (cpu_data_addr ),      // input wire [15 : 0] addra
//  .dina  (cpu_data_wdata),      // input wire [31 : 0] dina
//  .douta (cpu_data_rdata)      // output wire [31 : 0] douta
//);

sram_wrap u_base_ram_wrap(
	.clk   (clk_20M  ),
	.reset (cpu_reset),
	//receive from cpu
	.en    (cpu_inst_en   ),
	.wen   (cpu_inst_wen  ),
	.addr  (cpu_inst_addr ),
	.wdata (cpu_inst_wdata),
	.rdata (cpu_inst_rdata),
	//send to board
	.sram_data (base_ram_data),
	.sram_addr (base_ram_addr), 
    .sram_be_n (base_ram_be_n), 
	.sram_ce_n (base_ram_ce_n),
	.sram_oe_n (base_ram_oe_n),
	.sram_we_n (base_ram_we_n)
);
		
sram_wrap u_ext_ram_wrap(
	.clk   (clk_20M  ),
	.reset (cpu_reset),
	//receive from cpu
	.en    (cpu_data_en   ),
	.wen   (cpu_data_wen  ),
	.addr  (cpu_data_addr ),
	.wdata (cpu_data_wdata),
	.rdata (cpu_data_rdata),
	//send to board
	.sram_data (ext_ram_data),
	.sram_addr (ext_ram_addr), 
    .sram_be_n (ext_ram_be_n), 
	.sram_ce_n (ext_ram_ce_n),
	.sram_oe_n (ext_ram_oe_n),
	.sram_we_n (ext_ram_we_n)
);	













//wire[7:0] number;
//
////直连串口接收发送演示，从直连串口收到的数据再发送出去
//wire [7:0] ext_uart_rx;
//reg  [7:0] ext_uart_buffer, ext_uart_tx;
//wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
//reg ext_uart_start, ext_uart_avai;
//    
//assign number = ext_uart_buffer;
//
//async_receiver #(.ClkFrequency(50000000),.Baud(9600)) //接收模块，9600无检验位
//    ext_uart_r(
//        .clk(clk_50M),                       //外部时钟信号
//        .RxD(rxd),                           //外部串行信号输入
//        .RxD_data_ready(ext_uart_ready),  	 //数据接收到标志
//        .RxD_clear(ext_uart_clear),       	 //清除接收标志
//        .RxD_data(ext_uart_rx)               //接收到的一字节数据
//    );
//
//assign ext_uart_clear = ext_uart_ready; //收到数据的同时，清除标志，因为数据已取到ext_uart_buffer中
//always @(posedge clk_50M) begin //接收到缓冲区ext_uart_buffer
//    if(ext_uart_ready)begin
//        ext_uart_buffer <= ext_uart_rx;
//        ext_uart_avai <= 1;
//    end else if(!ext_uart_busy && ext_uart_avai)begin 
//        ext_uart_avai <= 0;
//    end
//end
//always @(posedge clk_50M) begin //将缓冲区ext_uart_buffer发送出去
//    if(!ext_uart_busy && ext_uart_avai)begin 
//        ext_uart_tx <= ext_uart_buffer;
//        ext_uart_start <= 1;
//    end else begin 
//        ext_uart_start <= 0;
//    end
//end
//
//async_transmitter #(.ClkFrequency(50000000),.Baud(9600)) //发送模块，9600无检验位
//    ext_uart_t(
//        .clk(clk_50M),                  //外部时钟信号
//        .TxD(txd),                      //串行信号输出
//        .TxD_busy(ext_uart_busy),       //发送器忙状态指示
//        .TxD_start(ext_uart_start),     //开始发送信号
//        .TxD_data(ext_uart_tx)          //待发送的数据
//    );


/* =========== Demo code end =========== */

endmodule
