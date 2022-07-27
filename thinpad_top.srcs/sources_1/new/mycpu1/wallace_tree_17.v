module wallace_tree_17 (
    input  wire[16:0] w_I,
    input  wire[13:0] cin,
    output wire       S  ,
    output wire       C  ,
    output wire[13:0] cout
);

wire [4:0] S_0_f;

//第0层华莱士树
full_adder_1 full_adder0(
    .A  (w_I[4]),
    .B  (w_I[3]),
    .Ci (w_I[2]),
    .S  (S_0_f[0]),
    .Co (cout[0])
);
full_adder_1 full_adder1(
    .A  (w_I[7]),
    .B  (w_I[6]),
    .Ci (w_I[5]),
    .S  (S_0_f[1]),
    .Co (cout[1])
);
full_adder_1 full_adder2(
    .A  (w_I[10]),
    .B  (w_I[9]),
    .Ci (w_I[8]),
    .S  (S_0_f[2]),
    .Co (cout[2])
);
full_adder_1 full_adder3(
    .A  (w_I[13]),
    .B  (w_I[12]),
    .Ci (w_I[11]),
    .S  (S_0_f[3]),
    .Co (cout[3])
);
full_adder_1 full_adder4(
    .A  (w_I[16]),
    .B  (w_I[15]),
    .Ci (w_I[14]),
    .S  (S_0_f[4]),
    .Co (cout[4])
);

//第1层华莱士树
wire [3:0] S_1_f;
full_adder_1 full_adder5(
    .A  (cin[2]),
    .B  (cin[1]),
    .Ci (cin[0]),
    .S  (S_1_f[0]),
    .Co (cout[5])
);
full_adder_1 full_adder6(
    .A  (cin[4]),
    .B  (cin[3]),
    .Ci (w_I[0]),
    .S  (S_1_f[1]),
    .Co (cout[6])
);
full_adder_1 full_adder7(
    .A  (w_I[1]),
    .B  (S_0_f[0]),
    .Ci (S_0_f[1]),
    .S  (S_1_f[2]),
    .Co (cout[7])
);
full_adder_1 full_adder8(
    .A  (S_0_f[2]),
    .B  (S_0_f[3]),
    .Ci (S_0_f[4]),
    .S  (S_1_f[3]),
    .Co (cout[8])
);

//第2层华莱士树
wire [1:0] S_2_f;
full_adder_1 full_adder9(
    .A  (cin[6]),
    .B  (cin[5]),
    .Ci (S_1_f[0]),
    .S  (S_2_f[0]),
    .Co (cout[9])
);
full_adder_1 full_adder10(
    .A  (S_1_f[1]),
    .B  (S_1_f[2]),
    .Ci (S_1_f[3]),
    .S  (S_2_f[1]),
    .Co (cout[10])
);

//第3层华莱士树
wire [1:0] S_3_f;
full_adder_1 full_adder11(
    .A  (cin[9]),
    .B  (cin[8]),
    .Ci (cin[7]),
    .S  (S_3_f[0]),
    .Co (cout[11])
);
full_adder_1 full_adder12(
    .A  (cin[10]),
    .B  (S_2_f[0]),
    .Ci (S_2_f[1]),
    .S  (S_3_f[1]),
    .Co (cout[12])
);

//第4层华莱士树
wire S_4_f;
full_adder_1 full_adder13(
    .A  (cin[11]),
    .B  (S_3_f[0]),
    .Ci (S_3_f[1]),
    .S  (S_4_f),
    .Co (cout[13])
);

//第5层华莱士树
full_adder_1 full_adder14(
    .A  (cin[13]),
    .B  (cin[12]),
    .Ci (S_4_f),
    .S  (S),
    .Co (C)
);

endmodule //wallace_tree_17