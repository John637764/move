`include "mycpu.h"

module id_stage(
    input  wire                           clk           ,
    input  wire                           reset         ,
    //allowin
    input  wire                           es_allowin    ,
    output wire                           ds_allowin    ,
    //from fs
    input  wire                           fs_to_ds_valid,
    input  wire [`FS_TO_DS_BUS_WD -1:0]   fs_to_ds_bus  ,
    //to es
    output wire                           ds_to_es_valid,
    output wire [`DS_TO_ES_BUS_WD -1:0]   ds_to_es_bus  ,
    //to fs
    output wire [`BR_BUS_WD       -1:0]   br_bus        ,
    //to rf: for write back
    input  wire [`WS_TO_RF_BUS_WD -1:0]   ws_to_rf_bus  ,
	//forward_bus
	input  wire [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
	input  wire [`FORWARD_BUS_WD -1:0]    ms_forward_bus,
	input  wire [`FORWARD_BUS_WD -1:0]    ws_forward_bus
);

reg          ds_valid   ;
wire         ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;
assign fs_pc = ds_pc + 32'd4;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [ 9:0] alu_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        imm_signed_ext;
wire        src2_is_8;
wire        gr_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

//算数运算类指令
wire inst_add;
wire inst_addi;
wire inst_addu;
wire inst_addiu;
wire inst_sub;
wire inst_slt;
wire inst_mul;
//逻辑运算类指令
wire inst_and;
wire inst_andi;
wire inst_lui;
wire inst_or;
wire inst_ori;
wire inst_xor;
wire inst_xori;
//移位指令
wire inst_sllv;
wire inst_sll;
wire inst_srav;
wire inst_sra;
wire inst_srlv;
wire inst_srl;
//分支跳转指令
wire inst_beq;
wire inst_bne;
wire inst_bgez;
wire inst_bgtz;
wire inst_blez;
wire inst_bltz;
wire inst_j;
wire inst_jal;
wire inst_jr;
wire inst_jalr;
//访存指令
wire inst_lb;
wire inst_lw;
wire inst_sb;
wire inst_sw;

wire es_rs_hazard;
wire es_rt_hazard;
wire ms_rs_hazard;
wire ms_rt_hazard;
wire ws_rs_hazard;
wire ws_rt_hazard;
wire [2:0] sel_rs;
wire [2:0] sel_rt;
wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire [4:0]  es_dest_reg;
wire [4:0]  ms_dest_reg;
wire [4:0]  ws_dest_reg;
wire [31:0] es_wreg_data;
wire [31:0] ms_wreg_data;
wire [31:0] ws_wreg_data;
wire        lw_read_after_write;
wire        es_forward_valid;
wire        ms_forward_valid;
wire        ws_forward_valid;

wire rs_eq_rt,rs_eq_zero,rs_g_zero,rs_l_zero;


assign br_bus       = {br_taken,br_target};
assign ds_to_es_bus = {imm_signed_ext,  //137:137
                       alu_op        ,  //136:127
					   inst_mul      ,  //126:126
					   inst_sb       ,	//125:125
					   inst_sw       ,	//124:124
					   inst_lb       ,  //123:123
					   inst_lw       ,	//122:122
					   src1_is_sa    ,  //121:121
                       src1_is_pc    ,  //120:120
                       src2_is_imm   ,  //119:119
                       src2_is_8     ,  //118:118
                       gr_we         ,  //117:117
                       dest          ,  //116:112
                       imm           ,  //111:96
                       rs_value      ,  //95 :64
                       rt_value      ,  //63 :32
                       ds_pc            //31 :0
                      };

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
assign ds_ready_go = ~(lw_read_after_write && (es_rs_hazard || es_rt_hazard));
always @(posedge clk) begin
	if(reset)begin
		ds_valid <= 1'b0;
	end
	else if(ds_allowin)begin
		ds_valid <= fs_to_ds_valid;
	end

	if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_mul    = op_d[6'h1c] & func_d[6'h02] & sa_d[5'h00];

assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e];

assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];

assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] &   rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] &   rt_d[5'h00];
assign inst_blez   = op_d[6'h06] &   rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] &   rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];

assign inst_lb     = op_d[6'h20];
assign inst_lw     = op_d[6'h23];
assign inst_sb     = op_d[6'h28];
assign inst_sw     = op_d[6'h2b];

assign alu_op[0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi |  
                   inst_jalr | inst_lb    | inst_sb;
assign alu_op[1] = inst_sub;
assign alu_op[2] = inst_slt;
assign alu_op[3] = inst_and | inst_andi;
assign alu_op[4] = inst_or  | inst_ori;
assign alu_op[5] = inst_xor | inst_xori;
assign alu_op[6] = inst_sll | inst_sllv;
assign alu_op[7] = inst_srl | inst_srlv;
assign alu_op[8] = inst_sra | inst_srav;
assign alu_op[9] = inst_lui;

assign src1_is_sa     = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc     = inst_jal   | inst_jalr;
assign src2_is_imm    = inst_addiu | inst_lui | inst_lw   | inst_sw | inst_addi |  
                        inst_andi  | inst_ori | inst_xori | inst_lb | inst_sb;						
assign imm_signed_ext = !(inst_andi| inst_ori | inst_xori);
assign src2_is_8      = inst_jal   | inst_jalr;
assign dst_is_r31     = inst_jal;
assign dst_is_rt      = inst_addiu | inst_lui | inst_lw   | inst_addi |  
                        inst_andi  | inst_ori | inst_xori | inst_lb;
assign gr_we          = ~inst_sw   & ~inst_beq  & ~inst_bne & ~inst_jr & ~inst_mul & ~inst_bgez & ~inst_bgtz  &
                        ~inst_blez & ~inst_bltz & ~inst_j   & ~inst_sb ;
assign dest           = dst_is_r31 ? 5'd31 :
                        dst_is_rt  ? rt    : 
                                     rd;

//read from regfile
assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

wire rs_is_not_zero;
wire rt_is_not_zero;
assign rs_is_not_zero = |rs;
assign rt_is_not_zero = |rt;
assign {lw_read_after_write,es_forward_valid,es_wreg_data,es_dest_reg} = es_forward_bus;
assign {ms_forward_valid,ms_wreg_data,ms_dest_reg} = ms_forward_bus;
assign {ws_forward_valid,ws_wreg_data,ws_dest_reg} = ws_forward_bus;
assign es_rs_hazard = (&(es_dest_reg ~^ rs)) & rs_is_not_zero & es_forward_valid;
assign es_rt_hazard = (&(es_dest_reg ~^ rt)) & rt_is_not_zero & es_forward_valid;
assign ms_rs_hazard = (&(ms_dest_reg ~^ rs)) & rs_is_not_zero & ms_forward_valid;
assign ms_rt_hazard = (&(ms_dest_reg ~^ rt)) & rt_is_not_zero & ms_forward_valid;
assign ws_rs_hazard = (&(ws_dest_reg ~^ rs)) & rs_is_not_zero & ws_forward_valid;
assign ws_rt_hazard = (&(ws_dest_reg ~^ rt)) & rt_is_not_zero & ws_forward_valid;

assign sel_rs = {es_rs_hazard,ms_rs_hazard,ws_rs_hazard};
assign sel_rt = {es_rt_hazard,ms_rt_hazard,ws_rt_hazard};
assign rs_value = (sel_rs[2]) ? es_wreg_data : 
                  (sel_rs[1]) ? ms_wreg_data :
                  (sel_rs[0]) ? ws_wreg_data :
                                    rf_rdata1;
assign rt_value = (sel_rt[2]) ? es_wreg_data :
                  (sel_rt[1]) ? ms_wreg_data :
                  (sel_rt[0]) ? ws_wreg_data :
                                    rf_rdata2;

assign rs_eq_rt = rs_value == rt_value;
assign rs_eq_zero = ~|rs_value;               
assign rs_g_zero  = ~rs_l_zero && ~rs_eq_zero;
assign rs_l_zero  = rs_value[31];
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
				   || inst_bgez && (rs_g_zero || rs_eq_zero)
				   || inst_bgtz &&  rs_g_zero
				   || inst_blez && (rs_l_zero || rs_eq_zero)
				   || inst_bltz &&  rs_l_zero
                   || inst_jal
                   || inst_jr
				   || inst_j
				   || inst_jalr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz) 
										  ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr) ? rs_value :
                                            {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule
