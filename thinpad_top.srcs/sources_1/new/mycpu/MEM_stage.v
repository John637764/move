`include "mycpu.h"

module mem_stage(
    input  wire                         clk           ,
    input  wire                         reset         ,
    //allowin
    input  wire                         ws_allowin    ,
    output wire                         ms_allowin    ,
    //from es
    input  wire                         es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output wire                         ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  wire [31                 :0] data_sram_rdata,
    input  wire [63                 :0] mul_result    ,
	//forward_bus
	output wire [`FORWARD_BUS_WD  -1:0] ms_forward_bus
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire        ms_inst_mul;
wire        ms_inst_lb;
wire        ms_inst_lw;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

assign {ms_inst_mul    ,  // 72:72
		ms_inst_lb     ,  // 71:71
		ms_inst_lw     ,  // 70:70        
        ms_gr_we       ,  // 69:69
        ms_dest        ,  // 68:64
        ms_alu_result  ,  // 63:32
        ms_pc             // 31:0
       } = es_to_ms_bus_r;

wire [31:0] lw_result;
wire [31:0] lb_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

	if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  = es_to_ms_bus;
    end
end

assign lw_result = data_sram_rdata;
assign lb_result = ms_alu_result[1:0] == 2'b00 ? {{24{data_sram_rdata[ 7]}},data_sram_rdata[ 7: 0]} : 
                   ms_alu_result[1:0] == 2'b01 ? {{24{data_sram_rdata[15]}},data_sram_rdata[15: 8]} :
                   ms_alu_result[1:0] == 2'b10 ? {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]} :
                                                   {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]} ;
assign ms_final_result = ms_inst_lw  ? lw_result  		:
						 ms_inst_lb  ? lb_result  		:
						 ms_inst_mul ? mul_result[31:0] :
                                       ms_alu_result;
//forward_bus
wire ms_forward_valid;
assign ms_forward_valid = ms_gr_we && ms_valid;
assign ms_forward_bus = {ms_forward_valid,ms_final_result,ms_dest};
endmodule
