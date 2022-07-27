`include "mycpu.h"

module exe_stage(
    input  wire                           clk           ,
    input  wire                           reset         ,
    //allowin
    input  wire                           ms_allowin    ,
    output wire                           es_allowin    ,
    //from ds
    input  wire                           ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD -1:0]   ds_to_es_bus  ,
    //to ms
    output wire                           es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD -1:0]   es_to_ms_bus  ,
	//forward_bus
	output wire [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
    // data sram interface
    output wire        data_sram_en   ,
    output wire [ 3:0] data_sram_wen  ,
    output wire [31:0] data_sram_addr ,
    output wire [31:0] data_sram_wdata,
    output wire [63:0] mul_result         
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;  
wire        es_imm_signed_ext;
wire [ 9:0] es_alu_op     ;
wire        es_inst_mul   ;
wire        es_inst_sb    ;
wire        es_inst_sw    ;
wire        es_inst_lb    ;
wire        es_inst_lw    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
assign {es_imm_signed_ext,  //137:137
        es_alu_op        ,  //136:127
        es_inst_mul      ,  //126:126
        es_inst_sb       ,	//125:125
        es_inst_sw       ,	//124:124
        es_inst_lb       ,  //123:123
        es_inst_lw       ,	//122:122
        es_src1_is_sa    ,  //121:121
        es_src1_is_pc    ,  //120:120
        es_src2_is_imm   ,  //119:119
        es_src2_is_8     ,  //118:118
        es_gr_we         ,  //117:117
        es_dest          ,  //116:112
        es_imm           ,  //111:96
        es_rs_value      ,  //95 :64
        es_rt_value      ,  //63 :32
        es_pc               //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

assign es_to_ms_bus = {es_inst_mul      ,  // 72:72
					   es_inst_lb       ,  // 71:71
					   es_inst_lw       ,  // 70:70
					   es_gr_we         ,  // 69:69
                       es_dest          ,  // 68:64
                       es_alu_result    ,  // 63:32
                       es_pc               // 31:0
                      };

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
	
    if(ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15] & es_imm_signed_ext}}, es_imm[15:0]} : 
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;


alu u_alu(
    .clk          (clk),
    .reset        (reset), 
    .alu_op       (es_alu_op),
    .alu_src1     (es_alu_src1),
    .alu_src2     (es_alu_src2),
    .alu_result   (es_alu_result),
	.mem_result   (data_sram_addr),
    .mul_result   (mul_result)
);

assign data_sram_en  = 1'b1;
assign data_sram_wen = es_inst_sw && es_valid ? 4'b1111 :
                       es_inst_sb && es_valid ? 
                          (data_sram_addr[1:0] == 2'b00 ? 4'b0001 :
                           data_sram_addr[1:0] == 2'b01 ? 4'b0010 :
                           data_sram_addr[1:0] == 2'b10 ? 4'b0100 :
                                                          4'b1000 ) :
												  4'b0000;

assign data_sram_wdata = es_inst_sb ? {4{es_rt_value[ 7:0]}} : es_rt_value;
//forward_bus
wire mem_read_after_write;
wire es_forward_valid;
assign mem_read_after_write = (es_inst_lb || es_inst_lw || es_inst_mul) && es_valid;
assign es_forward_valid = es_gr_we && es_valid;
assign es_forward_bus = {mem_read_after_write,es_forward_valid,es_alu_result,es_dest};
endmodule
