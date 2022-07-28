//*************************************************************************
//   > File Name   : confreg.v
//   > Description : Control module of a UART
//   > Author      : John
//   > Date        : 2022-07-17
//*************************************************************************

`define UART_DATA_ADDR 32'hbfd0_03f8  
`define UART_FLAG_ADDR 32'hbfd0_03fc

module confreg(                     
    input  wire clk,
    input  wire reset,     
    // read and write from cpu
	input  wire        conf_en,      
	input  wire [3 :0] conf_wen,      
	input  wire [31:0] conf_addr,    
	input  wire [31:0] conf_wdata,   
	output wire [31:0] conf_rdata,

    // read and write to device on board
	output wire txd,  //直连串口发送端
	input  wire rxd   //直连串口接收端
);

wire [7:0] uart_rdata;

reg 	  tx_start   ;
reg [7:0] ext_uart_tx;
always @(posedge clk)begin
	ext_uart_tx <= conf_wdata[7:0];
end
always @(posedge clk)begin
	if(reset)
		tx_start <= 1'b0;
	else
		tx_start <= conf_en & (|conf_wen);
end

reg  tx_flag;
wire tx_busy;
always @(posedge clk) begin
	if(reset)
		tx_flag <= 1'b1;
	else
		tx_flag <= ~tx_busy;
end

reg  rx_flag;
wire rx_valid;
always @(posedge clk) begin
	if(reset)
		rx_flag <= 1'b0;
	else 
		rx_flag <= rx_valid;
end

reg  data_revd;
always @(posedge clk) begin
	if(reset)
		data_revd <= 1'b1;
	else
		data_revd <= rx_valid && conf_addr == `UART_DATA_ADDR && conf_en;
end
                   
// read data has one cycle delay
reg [31:0] conf_rdata_reg;
always @(posedge clk)begin
	if(reset) begin
          conf_rdata_reg <= 32'd0;
	end
	else if (conf_en) begin
		case (conf_addr)
			`UART_DATA_ADDR : conf_rdata_reg <= {24'd0,uart_rdata};
			`UART_FLAG_ADDR : conf_rdata_reg <= {30'd0,rx_flag,tx_flag};
			default : conf_rdata_reg <= 32'd0;
		endcase
	end
end
assign conf_rdata = conf_rdata_reg;


uart #(.ClkFrequency(50000000),.Baud(9600))
	uart1(
		.clk   			(clk  	   ),
		.rxd            (rxd       ),
		.ext_uart_ready (rx_valid  ),
		.ext_uart_clear (data_revd ),
		.ext_uart_rx    (uart_rdata),
		              
		.txd            (txd         ),
		.ext_uart_busy  (tx_busy     ),
		.ext_uart_start (tx_start    ),
		.ext_uart_tx    (ext_uart_tx )
);

endmodule