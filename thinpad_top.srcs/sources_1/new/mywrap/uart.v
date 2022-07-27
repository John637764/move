module uart(
	input  wire clk  ,

	input  wire 	  rxd,
	output wire 	  ext_uart_ready,
	input  wire 	  ext_uart_clear,
	output wire [7:0] ext_uart_rx   ,
	             
	output wire       txd           ,
	output wire       ext_uart_busy ,
	input  wire       ext_uart_start,	
	input  wire [7:0] ext_uart_tx   		
);

parameter ClkFrequency = 50000000;	// 20MHz
parameter Baud = 9600;

async_receiver #(.ClkFrequency(ClkFrequency),.Baud(Baud)) //接收模块，9600无检验位
    ext_uart_r(
        .clk(clk),                       	 //外部时钟信号
        .RxD(rxd),                           //外部串行信号输入
        .RxD_data_ready(ext_uart_ready),  	 //数据接收到标志
        .RxD_clear(ext_uart_clear),       	 //清除接收标志
        .RxD_data(ext_uart_rx)               //接收到的一字节数据
    );

async_transmitter #(.ClkFrequency(ClkFrequency),.Baud(Baud)) //发送模块，9600无检验位
    ext_uart_t(
        .clk(clk),                  	//外部时钟信号
        .TxD(txd),                      //串行信号输出
        .TxD_busy(ext_uart_busy),       //发送器忙状态指示
        .TxD_start(ext_uart_start),     //开始发送信号
        .TxD_data(ext_uart_tx)          //待发送的数据
    );


endmodule