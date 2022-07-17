module booth2(
    input  wire [63:0] X,
    input  wire [ 2:0] y,
    output wire [63:0] p,
    output wire        c
);
wire [7:0] B;
genvar i;
generate
    for(i=0;i<8;i=i+1)begin
        :Booth_judge_singals
        assign B[i] = (y == i);
    end
endgenerate 

//选择输出的控制信号
wire add_zero;
wire add_X   ;
wire add_X_n ;
wire add_2X  ;
wire add_2X_n;
assign add_zero = B[7] | B[0];
assign add_X    = B[1] | B[2];
assign add_X_n  = B[5] | B[6];
assign add_2X   = B[3]       ;
assign add_2X_n = B[4]       ;

//输出部分积为输入信号相反数时为取反后的数加1得到相反数的补码
assign c = add_X_n | add_2X_n;

//输出部分积
assign p = add_X    ?  X[63:0]        :
           add_X_n  ? ~X[63:0]        :
           add_2X   ?  {X[62:0],1'b0} :
           add_2X_n ? ~{X[62:0],1'b0} :
           64'b0;
endmodule