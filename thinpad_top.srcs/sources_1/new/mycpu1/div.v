module div (
    input  wire        div_clk    , 
	input  wire        reset      , 
	input  wire        div        , 
	input  wire        div_signed , 
	input  wire [31:0] x          , 
	input  wire [31:0] y          , 
	output wire [31:0] s          , 
	output wire [31:0] r          , 
	output wire        complete
);

//counter
wire counter_en;
reg  [5:0] count;
assign counter_en = ~reset & div;
always @(posedge div_clk)begin
    if(!counter_en)
        count <= 6'b0;
    else
        count <= count + 1;
end

wire divisor_s;    //被除数正负
wire divider_s;    //除数正负
wire remainder_s;  //余数正负
wire quotient_s;   //商正负
assign divisor_s   = div_signed & x[31];
assign divider_s   = div_signed & y[31];
assign remainder_s = divisor_s;
assign quotient_s  = div_signed & (x[31] ^ y[31]); 

wire [31:0] divisor_abs_32;
wire [31:0] divider_abs_32;
wire [63:0] divisor_abs_64;
wire [32:0] divider_abs_33;
reg  [63:0] result_abs_buffer; //结果绝对值缓存

wire [31:0] opposite_i_1;      //输入到取反加1部件的信号 
wire [31:0] opposite_i_2;      //输入到取反加1部件的信号
wire [31:0] opposite_o_1;      //输入到取反加1部件的信号 
wire [31:0] opposite_o_2;      //输入到取反加1部件的信号

assign opposite_i_1 = complete ? result_abs_buffer[63:32] : x ;
assign opposite_i_2 = complete ? result_abs_buffer[31: 0] : y ;     
assign opposite_o_1 = ~opposite_i_1 + 1;
assign opposite_o_2 = ~opposite_i_2 + 1;

assign divisor_abs_32 = divisor_s ? opposite_o_1 : x;
assign divider_abs_32 = divider_s ? opposite_o_2 : y;
assign divisor_abs_64 = {32'b0,divisor_abs_32};
assign divider_abs_33 = {1'b0,divider_abs_32};

wire[32:0] sub_result;
wire [63:0] update_result;
assign sub_result = result_abs_buffer[63:31] - divider_abs_33;
assign update_result = {(sub_result[32] ? result_abs_buffer[62:31] : sub_result[31:0]),
                        result_abs_buffer[30:0],(sub_result[32] ? 1'b0 : 1'b1)};

always @(posedge div_clk)begin
    if(count == 6'b0)
        result_abs_buffer <= divisor_abs_64;
    else if(div)
        result_abs_buffer <= update_result;
end

assign complete = div && (count == 33);
assign s = quotient_s ? opposite_o_2 : result_abs_buffer[31:0];
assign r = remainder_s ? opposite_o_1 : result_abs_buffer[63:32];
endmodule