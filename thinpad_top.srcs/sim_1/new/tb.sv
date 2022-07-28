`timescale 1ns / 1ps

module tb;
parameter SIMULATION = 1'b1;

wire clk_50M, clk_11M0592;

reg reset_btn = 0;         //BTN6手动复位按钮开关，带消抖电路，按下时为1

wire txd;  //直连串口发送端
wire rxd;  //直连串口接收端

wire[31:0] base_ram_data; //BaseRAM数据，低8位与CPLD串口控制器共享
wire[19:0] base_ram_addr; //BaseRAM地址
wire[3:0] base_ram_be_n;  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire base_ram_ce_n;       //BaseRAM片选，低有效
wire base_ram_oe_n;       //BaseRAM读使能，低有效
wire base_ram_we_n;       //BaseRAM写使能，低有效

wire[31:0] ext_ram_data; //ExtRAM数据
wire[19:0] ext_ram_addr; //ExtRAM地址
wire[3:0] ext_ram_be_n;  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire ext_ram_ce_n;       //ExtRAM片选，低有效
wire ext_ram_oe_n;       //ExtRAM读使能，低有效
wire ext_ram_we_n;       //ExtRAM写使能，低有效

wire [22:0]flash_a;      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
wire [15:0]flash_d;      //Flash数据
wire flash_rp_n;         //Flash复位信号，低有效
wire flash_vpen;         //Flash写保护信号，低电平时不能擦除、烧写
wire flash_ce_n;         //Flash片选信号，低有效
wire flash_oe_n;         //Flash读使能信号，低有效
wire flash_we_n;         //Flash写使能信号，低有效
wire flash_byte_n;       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

//Windows需要注意路径分隔符的转义，例如"D:\\foo\\bar.bin"
parameter BASE_RAM_INIT_FILE = "D:\\NSCSCC\\NSCSCC2022\\2022021\\kernel.bin"; //BaseRAM初始化文件，请修改为实际的绝对路径
parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";    //ExtRAM初始化文件，请修改为实际的绝对路径
parameter FLASH_INIT_FILE = "/tmp/kernel.elf";    //Flash初始化文件，请修改为实际的绝对路径



initial begin 
    //在这里可以自定义测试输入序列，例如：
    reset_btn = 1;
    #100;
    reset_btn = 0;
    
end

// 待测试用户设计
thinpad_top #(.SIMULATION(SIMULATION)) dut 
(
    .clk_50M(clk_50M),
    .reset_btn(reset_btn),
    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_be_n(base_ram_be_n),
    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),
    .ext_ram_be_n(ext_ram_be_n),
	
	.txd(txd),
    .rxd(rxd)
);
// 时钟源
clock osc(
    .clk_11M0592(clk_11M0592),
    .clk_50M    (clk_50M)
);

// BaseRAM 仿真模型
sram_model base1(/*autoinst*/
            .DataIO(base_ram_data[15:0]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[0]),
            .UB_n(base_ram_be_n[1]));
sram_model base2(/*autoinst*/
            .DataIO(base_ram_data[31:16]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[2]),
            .UB_n(base_ram_be_n[3]));
// ExtRAM 仿真模型
sram_model ext1(/*autoinst*/
            .DataIO(ext_ram_data[15:0]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[0]),
            .UB_n(ext_ram_be_n[1]));
sram_model ext2(/*autoinst*/
            .DataIO(ext_ram_data[31:16]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[2]),
            .UB_n(ext_ram_be_n[3]));
/*
// Flash 仿真模型
x28fxxxp30 #(.FILENAME_MEM(FLASH_INIT_FILE)) flash(
    .A(flash_a[1+:22]), 
    .DQ(flash_d), 
    .W_N(flash_we_n),    // Write Enable 
    .G_N(flash_oe_n),    // Output Enable
    .E_N(flash_ce_n),    // Chip Enable
    .L_N(1'b0),    // Latch Enable
    .K(1'b0),      // Clock
    .WP_N(flash_vpen),   // Write Protect
    .RP_N(flash_rp_n),   // Reset/Power-Down
    .VDD('d3300), 
    .VDDQ('d3300), 
    .VPP('d1800), 
    .Info(1'b1));
*/
/*
initial begin 
    wait(flash_byte_n == 1'b0);
    $display("8-bit Flash interface is not supported in simulation!");
    $display("Please tie flash_byte_n to high");
    $stop;
end
*/

// 从文件加载 BaseRAM
initial begin 
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(BASE_RAM_INIT_FILE, "rb");
    if(!n_File_ID)begin 
        n_Init_Size = 0;
        $display("Failed to open BaseRAM init file");
    end else begin
        n_Init_Size = $fread(tmp_array, n_File_ID);
        n_Init_Size /= 4;
        $fclose(n_File_ID);
    end
    $display("BaseRAM Init Size(words): %d",n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
        base1.mem_array0[i] = tmp_array[i][24+:8];
        base1.mem_array1[i] = tmp_array[i][16+:8];
        base2.mem_array0[i] = tmp_array[i][8+:8];
        base2.mem_array1[i] = tmp_array[i][0+:8];
    end
end
/*
// 从文件加载 ExtRAM
initial begin 
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(EXT_RAM_INIT_FILE, "rb");
    if(!n_File_ID)begin 
        n_Init_Size = 0;
        $display("Failed to open ExtRAM init file");
    end else begin
        n_Init_Size = $fread(tmp_array, n_File_ID);
        n_Init_Size /= 4;
        $fclose(n_File_ID);
    end
    $display("ExtRAM Init Size(words): %d",n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
        ext1.mem_array0[i] = tmp_array[i][24+:8];
        ext1.mem_array1[i] = tmp_array[i][16+:8];
        ext2.mem_array0[i] = tmp_array[i][8+:8];
        ext2.mem_array1[i] = tmp_array[i][0+:8];
    end
end
*/
`define TEST_ADDR   32'h80100000
`define CRYPTONIGHT 32'h800030c4
`define STREAM		32'h8000300c
`define MATRIX		32'h8000303c
`define ORDER_G		 8'h47
`define ORDER_D 	 8'h44
`define TEST_NUM     8'h8

wire 	   test_rready;
wire 	   test_rclear;
wire [7:0] test_rdata ;
wire 	   test_tbusy ;
reg  	   test_tstart;
wire [7:0] test_tdata ;

reg [2:0] task_cnt;

assign test_rclear = test_rready;

async_receiver #(.ClkFrequency(50000000),.Baud(1152000)) //接收模块，9600无检验位
    test_uart_r(
        .clk		    (clk_50M	),          //外部时钟信号
        .RxD		    (txd		),          //外部串行信号输入
        .RxD_data_ready (test_rready),  	 	//数据接收到标志
        .RxD_clear	    (test_rclear),       	//清除接收标志
        .RxD_data 	    (test_rdata )           //接收到的一字节数据
    );

async_transmitter #(.ClkFrequency(50000000),.Baud(1152000)) //发送模块，9600无检验位
    test_uart_t(
        .clk	   (clk_50M    ),               //外部时钟信号
        .TxD	   (rxd        ),               //串行信号输出
        .TxD_busy  (test_tbusy ),       		//发送器忙状态指示
        .TxD_start (test_tstart),     			//开始发送信号
        .TxD_data  (test_tdata )          		//待发送的数据
    );

reg [ 7:0] rdata_buf  ;
reg 	   rdata_buf_v;
reg [55:0] tx_buf	  ;
always @(posedge clk_50M) begin
	if(reset_btn)
		tx_buf <= {`TEST_NUM,`TEST_ADDR,`ORDER_D,8'h0};
	else if(rdata_buf == 8'h2e && ~test_tbusy)
		tx_buf <= tx_buf >> 8;
end
assign test_tdata = tx_buf;

always @(posedge clk_50M) begin
	if(reset_btn)
		rdata_buf <= 8'b0;
	else if(test_rready)
		rdata_buf 	<= test_rdata;
end
always @(posedge clk_50M) begin
	if(reset_btn)
		rdata_buf_v <= 1'b0;
	else
		rdata_buf_v <= test_rready;
end

initial begin
	$display("==============================================================");
    $display("==============================================================");
    $display("=================   CRYPTONIGHT Test begin!   ================");
end

reg stop_r;
always @(posedge clk_50M)begin
	if(reset_btn)
		stop_r <= 1'b0;
	else if(~|tx_buf)
		stop_r <= 1'b1;
end

always @(posedge clk_50M) begin
	if(rdata_buf_v) begin
		case(rdata_buf)
			8'h4d:$display("M");
			8'h4f:$display("O");
			8'h4e:$display("N");
			8'h49:$display("I");
			8'h54:$display("T");
			8'h52:$display("R");
			8'h20:$display(" ");
			8'h66:$display("f");
			8'h6f:$display("o");
			8'h72:$display("r");
			8'h50:$display("P");
			8'h53:$display("S");
			8'h33:$display("3");
			8'h32:$display("2");
			8'h2d:$display("-");
			8'h69:$display("i");
			8'h6e:$display("n");
			8'h74:$display("t");
			8'h61:$display("a");
			8'h6c:$display("l");
			8'h7a:$display("z");
			8'h65:$display("e");
			8'h64:$display("d");
			8'h2e:$display(".");
			8'h06:$display("test begin");
			8'h07:$display("test end");
			default:
			begin
				$display("==============================================================");
				$display("uart tx version err");
				$display("==============================================================");
				$stop;
			end
		endcase
	end
end

always @(posedge clk_50M) begin
	if(reset_btn)
		test_tstart <= 1'b0;
	else if(rdata_buf == 8'h2e && ~test_tbusy)
		test_tstart <= 1'b1;
end

reg stop_r;
always @(posedge clk_50M)begin
	if(reset_btn)
		stop_r <= 1'b0;
	else if(~|tx_buf)
		stop_r <= 1'b1;
end

reg [2:0] send_cnt;
always @(posedge clk_50M) begin
	if(reset_btn)
		send_cnt <= 1'b0;
	else if(rdata_buf == 8'h2e && ~test_tbusy && |tx_buf)
		send_cnt <= send_cnt + 1;
end

always @(posedge clk_50M) begin
	if(~|tx_buf && ~stop_r)
		$display("=========================   Send 'G' finshed  ===========================");
end

always @(posedge clk_50M) begin
	if(rdata_buf == 8'h07)
		$finish;
end

endmodule
