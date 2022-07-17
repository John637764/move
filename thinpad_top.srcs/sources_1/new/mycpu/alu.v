module alu(
  input  wire        clk         ,
  input  wire        reset       , 
  input  wire [ 9:0] alu_op      ,
  input  wire [31:0] alu_src1    ,
  input  wire [31:0] alu_src2    ,
  output wire [31:0] alu_result  ,
  output wire [31:0] mem_result  ,
  output wire [63:0] mul_result
);

wire op_add;   //CPU执行加法操作
wire op_sub;   //CPU执行减法操作
wire op_slt;   //CPU执行有符号数比较操作
wire op_and;   //CPU执行与操作
wire op_or ;   //CPU执行或操作
wire op_xor;   //CPU执行异或操作
wire op_sll;   
wire op_srl;   
wire op_sra;   
wire op_lui;   

// control code decomposition
assign op_add    = alu_op[0];
assign op_sub    = alu_op[1];
assign op_slt    = alu_op[2];
assign op_and    = alu_op[3];
assign op_or     = alu_op[4];
assign op_xor    = alu_op[5];
assign op_sll    = alu_op[6];
assign op_srl    = alu_op[7];
assign op_sra    = alu_op[8];
assign op_lui    = alu_op[9];

wire [31:0] add_sub_result; 
wire [31:0] slt_result; 
wire [31:0] and_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result; 
wire [63:0] sr64_result; 
wire [31:0] sr_result; 

mul u_mul(
    .mul_clk    (clk),
    .reset      (reset),
    .mul_signed (1'b1),
    .x          (alu_src1),
    .y          (alu_src2),
    .result     (mul_result)
);

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt) ? ~alu_src2 : alu_src2;
assign adder_cin = (op_sub | op_slt) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = {alu_src2[15:0], 16'b0};
// SLL result 
assign sll_result = alu_src2 << alu_src1[4:0];

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0];
assign sr_result   = sr64_result[31:0];

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result);
assign mem_result = add_sub_result;
endmodule
