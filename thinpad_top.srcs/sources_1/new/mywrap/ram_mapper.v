`define BASE_RAM_ADDR  32'h8000_0000
`define EXT_RAM_ADDR   32'h8040_0000
`define RAM_LIMIT_ADDR 32'h8080_0000

module ram_mapper(
	input  clk   ,
	input  reset ,
    // inst sram interface
    input  wire        inst_sram_en,
    input  wire [ 3:0] inst_sram_wen,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    output wire [31:0] inst_sram_rdata,
    // data sram interface
    input  wire        data_sram_en,
    input  wire [ 3:0] data_sram_wen,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    output wire [31:0] data_sram_rdata,	
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
);

wire        base_en   ;
wire [ 3:0] base_wen  ;
wire [31:0] base_addr ;
wire [31:0] base_wdata;
wire [31:0] base_rdata;

wire        ext_en   ;
wire [ 3:0] ext_wen  ;
wire [31:0] ext_addr ;
wire [31:0] ext_wdata;
wire [31:0] ext_rdata;

assign base_en = 
assign ext_en  = 

sram_wrap u_base_ram_wrap(
	.clk   (clk  ),
	.reset (reset),
	//receive from cpu
	.en    (base_en   ),
	.wen   (base_wen  ),
	.addr  (base_addr ),
	.wdata (base_wdata),
	.rdata (base_rdata),
	//send to board
	.sram_data (base_ram_data),
	.sram_addr (base_ram_addr), 
    .sram_be_n (base_ram_be_n), 
	.sram_ce_n (base_ram_ce_n),
	.sram_oe_n (base_ram_oe_n),
	.sram_we_n (base_ram_we_n)
);
	
sram_wrap u_ext_ram_wrap(
	.clk   (clk  ),
	.reset (reset),
	//receive from cpu
	.en    (ext_en   ),
	.wen   (ext_wen  ),
	.addr  (ext_addr ),
	.wdata (ext_wdata),
	.rdata (ext_rdata),
	//send to board
	.sram_data (ext_ram_data),
	.sram_addr (ext_ram_addr), 
    .sram_be_n (ext_ram_be_n), 
	.sram_ce_n (ext_ram_ce_n),
	.sram_oe_n (ext_ram_oe_n),
	.sram_we_n (ext_ram_we_n)
);	
	
endmodule