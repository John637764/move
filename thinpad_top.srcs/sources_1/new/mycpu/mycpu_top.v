`default_nettype none

module mycpu_top(
    input  wire         clk  ,
    input  wire         reset,
	//Cache与sram接口的交互接口
    output wire         i_rd_req 	 ,   //读请求有效信号，高电平有效
    output wire [  2:0] i_rd_type	 ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    output wire [ 31:0] i_rd_addr	 ,   //读请求起始地址
    input  wire         i_rd_rdy 	 ,   //读请求能否被接收的握手信号，高电平有效
    input  wire         i_ret_valid  ,   //返回数据有效信号，高电平有效
    input  wire  	    i_ret_last   ,   //返回数据是1次读请求对应的最后1个返回数据
    input  wire [ 31:0] i_ret_data   ,   //读返回数据
	input  wire		 	i_wr_rdy     ,
	
    output wire         d_rd_req 	 ,   //读请求有效信号，高电平有效
    output wire [  2:0] d_rd_type	 ,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    output wire [ 31:0] d_rd_addr	 ,   //读请求起始地址
    input  wire         d_rd_rdy 	 ,   //读请求能否被接收的握手信号，高电平有效
    input  wire         d_ret_valid  ,   //返回数据有效信号，高电平有效
    input  wire 	    d_ret_last   ,   //返回数据是1次读请求对应的最后1个返回数据
    input  wire [ 31:0] d_ret_data   ,   //读返回数据

    output wire         d_wr_req     ,   //写请求有效信号，高电平有效
    output wire [  2:0] d_wr_type    ,   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    output wire [ 31:0] d_wr_addr    ,   //写请求起始地址
    output wire [  3:0] d_wr_wstrb   ,   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    output wire [127:0] d_wr_data    ,   //写数据
    input  wire         d_wr_rdy     ,   //写请求能否被接收的握手信号，高电平有效
	input  wire         d_wr_wvalid  ,   //uncached的写请求响应
	input  wire         d_wr_wlast   ,   //uncached的写请求响应
		
    // trace debug interface
    output wire [31:0]  debug_wb_pc      ,
    output wire [ 3:0]  debug_wb_rf_wen  ,
    output wire [ 4:0]  debug_wb_rf_wnum ,
    output wire [31:0]  debug_wb_rf_wdata
);

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0]   fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0]   ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0]   es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0]   ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0]   ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0]   br_bus;
wire [`ES_FORWARD_BUS_WD -1:0] es_forward_bus;
wire [`FORWARD_BUS_WD -1:0]    ms_forward_bus;
wire [`FORWARD_BUS_WD -1:0]    ws_forward_bus;

wire [63:0] mul_result;
wire        inst_req      ;
wire [ 3:0] inst_wstrb    ;
wire [31:0] inst_vaddr    ;
wire [31:0] inst_wdata    ;
wire        inst_wr       ;     
wire [ 1:0] inst_size     ;    
wire        inst_addr_ok  ;
wire        inst_data_ok  ;
wire [31:0] inst_rdata    ;

wire        data_req      ;
wire [ 3:0] data_wstrb    ;
wire [31:0] data_vaddr    ;
wire [31:0] data_wdata    ;
wire        data_wr       ;   
wire [ 1:0] data_size     ;   
wire        data_addr_ok  ;
wire        data_data_ok  ;
wire [31:0] data_rdata    ;

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_req       (inst_req       ),
    .inst_wstrb     (inst_wstrb     ),
    .inst_vaddr     (inst_vaddr     ),
    .inst_wdata     (inst_wdata     ),
    .inst_wr        (inst_wr        ),
    .inst_size      (inst_size      ),
    .inst_addr_ok   (inst_addr_ok   ),
    .inst_data_ok   (inst_data_ok   ),
    .inst_rdata     (inst_rdata     )   
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
	//forward_bus
	.es_forward_bus (es_forward_bus ),
	.ms_forward_bus (ms_forward_bus ),
	.ws_forward_bus (ws_forward_bus )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_req     	(data_req       ),
    .data_wstrb   	(data_wstrb     ),
    .data_vaddr	    (data_vaddr     ),
    .data_wdata   	(data_wdata     ),
    .data_wr      	(data_wr        ),
    .data_size    	(data_size      ),
    .data_addr_ok 	(data_addr_ok   ),
    .mul_result     (mul_result     ),       
	//exe_forward
	.es_forward_bus (es_forward_bus )   
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-cache
	.data_rdata     (data_rdata     ),
	.data_data_ok   (data_data_ok   ),
	
    .mul_result     (mul_result     ),
	.ms_forward_bus (ms_forward_bus )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
	.ws_forward_bus   (ws_forward_bus)
);

cache icache(
    .clk       (clk  ),
    .reset     (reset),
    // Cache与CPU流水线的交互接口
	.c		   (3'h2	          ),     //cache属性
	.valid     (inst_req          ),     //表明请求有效
    .op        (inst_wr           ),     //1：write  0：read
    .index     (inst_vaddr[11: 4] ),     //addr[11: 4]
    .tag       (inst_vaddr[31:12] ),     //addr[31:12]
    .offset    (inst_vaddr[ 3: 0] ),     //addr[ 3: 0]
    .wstrb     (inst_wstrb        ),     //字节写使能
    .wdata     (inst_wdata        ),     //写入数据
    .addr_ok   (inst_addr_ok      ),     //该次请求的地址传输OK，读：地址被接收； 写：地址和数据被接收
    .data_ok   (inst_data_ok      ),     //该次请求的数据传输OK，读：数据返回；   写：数据写入完成
    .rdata     (inst_rdata        ),     //读Cache的结果
	//Cache与AXI总线接口的交互接口
    .rd_req    (i_rd_req   ),   //读请求有效信号，高电平有效
    .rd_type   (i_rd_type  ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .rd_addr   (i_rd_addr  ),   //读请求起始地址
    .rd_rdy    (i_rd_rdy   ),   //读请求能否被接收的握手信号，高电平有效
    .ret_valid (i_ret_valid),   //返回数据有效信号，高电平有效
    .ret_last  (i_ret_last ),   //返回数据是1次读请求对应的最后1个返回数据
    .ret_data  (i_ret_data ),   //读返回数据

    .wr_req    (	       ),   //写请求有效信号，高电平有效
    .wr_type   (		   ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .wr_addr   (		   ),   //写请求起始地址
    .wr_wstrb  (		   ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    .wr_data   (		   ),   //写数据
    .wr_rdy    (i_wr_rdy   ),   //写请求能否被接收的握手信号，高电平有效
	.wr_wvalid (1'b0       ),   //uncached的写请求响应
	.wr_wlast  (1'b0       )  	//uncached的写请求响应
);

cache dcache(
    .clk       (clk  ),
    .reset     (reset),
    // Cache与CPU流水线的交互接口
	.c	       (3'h2),//{3{data_vaddr!=32'hbfd0_03f8 && data_vaddr!=32'hbfd0_03fc}}	& 3'h3),     //cache属性
	.valid     (data_req              ),     //表明请求有效
    .op        (data_wr               ),     //1：write  0：read
    .index     (data_vaddr[11: 4] 	  ),     //addr[11: 4]
    .tag       (data_vaddr[31:12] 	  ),     //addr[31:12]
    .offset    (data_vaddr[ 3: 0] 	  ),     //addr[ 3: 0]
    .wstrb     (data_wstrb            ),     //字节写使能
    .wdata     (data_wdata            ),     //写入数据
    .addr_ok   (data_addr_ok          ),     //该次请求的地址传输OK，读：地址被接收； 写：地址和数据被接收
    .data_ok   (data_data_ok          ),     //该次请求的数据传输OK，读：数据返回；   写：数据写入完成
    .rdata     (data_rdata            ),     //读Cache的结果
	//Cache与AXI总线接口的交互接口
    .rd_req    (d_rd_req   ),   //读请求有效信号，高电平有效
    .rd_type   (d_rd_type  ),   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .rd_addr   (d_rd_addr  ),   //读请求起始地址
    .rd_rdy    (d_rd_rdy   ),   //读请求能否被接收的握手信号，高电平有效
    .ret_valid (d_ret_valid),   //返回数据有效信号，高电平有效
    .ret_last  (d_ret_last ),   //返回数据是1次读请求对应的最后1个返回数据
    .ret_data  (d_ret_data ),   //读返回数据

    .wr_req    (d_wr_req   ),   //写请求有效信号，高电平有效
    .wr_type   (d_wr_type  ),   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    .wr_addr   (d_wr_addr  ),   //写请求起始地址
    .wr_wstrb  (d_wr_wstrb ),   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    .wr_data   (d_wr_data  ),   //写数据
    .wr_rdy    (d_wr_rdy   ),   //写请求能否被接收的握手信号，高电平有效
	.wr_wvalid (d_wr_wvalid),   //uncached的写请求响应
	.wr_wlast  (d_wr_wlast )  	//uncached的写请求响应
);


endmodule
