`include "mycpu.h"

module if_stage(
    input  wire                         clk            ,
    input  wire                         reset          ,
    //allwoin
    input  wire                         ds_allowin     ,
    //brbus
    input  wire [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output wire                         fs_to_ds_valid ,
    output wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output wire        inst_req     ,
    output wire [ 3:0] inst_wstrb   ,
    output wire [31:0] inst_vaddr   ,
    output wire [31:0] inst_wdata   ,
    output wire        inst_wr      ,
    output wire [ 1:0] inst_size    ,
    input  wire        inst_addr_ok ,
    input  wire        inst_data_ok ,
    input  wire [31:0] inst_rdata      
);
reg  [31:0] fs_pc     ;
reg         fs_valid  ;
wire        fs_allowin;
// pre-IF stage
wire 		ps_to_fs_valid;
wire 		ps_valid;
wire 		ps_ready_go;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_stall;
wire        br_taken;
wire [31:0] br_target;
assign {br_stall,br_taken,br_target} = br_bus;
/*ps state machine*/
reg  [ 2:0] ps_pre_state;
wire [ 2:0] ps_next_state;
parameter ADD_4                  = 3'd0;
parameter WAIT_READY_GO          = 3'd1;
parameter STORE_BR_ADDR          = 3'd2;
parameter USE_STORED_BR_ADDR     = 3'd3;
parameter USE_CURRENT_BR_ADDR    = 3'd4;

always @(posedge clk ) begin
    if(reset)
        ps_pre_state <= ADD_4;
    else
        ps_pre_state <= ps_next_state;
end

assign ps_next_state = ps_pre_state == ADD_4 || ps_pre_state == WAIT_READY_GO ? 
                       (   
                           (br_taken && !ps_ready_go &&  fs_valid && !br_stall) || 
                           (br_taken &&  ps_ready_go && !fs_valid && !br_stall)    ? USE_CURRENT_BR_ADDR :
                           br_taken  && !ps_ready_go && !fs_valid && !br_stall     ? STORE_BR_ADDR       :
                           ps_ready_go                                             ? ADD_4               :
                           WAIT_READY_GO
                       ):
                       ps_pre_state == STORE_BR_ADDR ?
                       (
                           ps_ready_go ? USE_STORED_BR_ADDR : STORE_BR_ADDR
                       ):
                       ps_pre_state == USE_CURRENT_BR_ADDR ?
                       (
                           ps_ready_go ? ADD_4 : WAIT_READY_GO
                       ):
                       ps_pre_state == USE_STORED_BR_ADDR ?
                       (
                           ps_ready_go ? ADD_4 : WAIT_READY_GO
                       ):
                       ps_pre_state;

reg [31:0] br_target_r;
always @(posedge clk ) begin
    if(ps_next_state == STORE_BR_ADDR || ps_next_state == USE_CURRENT_BR_ADDR)
        br_target_r <= br_target;
end

reg [31:0] ps_pc_hold;
always @(posedge clk ) begin
    if(ps_next_state == WAIT_READY_GO)
        ps_pc_hold <= nextpc;
end

assign ps_valid = ~reset;
assign nextpc   = ps_pre_state == USE_CURRENT_BR_ADDR ||  
                  ps_pre_state == USE_STORED_BR_ADDR   ? br_target_r :
                  ps_pre_state == WAIT_READY_GO        ? ps_pc_hold  :
                                                         seq_pc      ;
assign ps_ready_go    = inst_addr_ok && inst_req;
assign ps_to_fs_valid = ps_valid && ps_ready_go;

assign seq_pc    = fs_pc + 3'h4;
assign inst_req  = !reset && !br_taken && fs_allowin;
 																	

// IF stage
reg         inst_file_valid     ;
reg  [31:0] inst_file           ;
wire        fs_ready_go;
wire [31:0] fs_inst    ;

assign fs_allowin = (!fs_valid || fs_ready_go) && ds_allowin;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= ps_to_fs_valid;
    end

    if (reset) begin
        fs_pc <=  32'h7ffffffc;  
    end
    else if (ps_to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end


assign fs_ready_go    = inst_data_ok || inst_file_valid;
always @(posedge clk ) begin
    if(reset)
        inst_file_valid <= 1'b0;
    else if(inst_data_ok && !ds_allowin)
        inst_file_valid <= 1'b1;
    else if(inst_file_valid && ds_allowin)
        inst_file_valid <= 1'b0;
end

assign fs_to_ds_valid = (fs_valid || inst_file_valid) && fs_ready_go;
assign fs_inst        = inst_file_valid ? inst_file : inst_rdata;
always @(posedge clk ) begin
    if(inst_data_ok && !ds_allowin)
        inst_file <= inst_rdata;
end

assign fs_to_ds_bus = {fs_inst, //63:32
                       fs_pc    //31: 0      
                      };

assign inst_wstrb = 4'h0;
assign inst_wr    = 1'b0;
assign inst_size  = 2'b10;
assign inst_vaddr = nextpc;
assign inst_wdata = 32'b0;

endmodule
