module full_adder_1 (
    input  wire A ,
    input  wire B ,
    input  wire Ci,
    output wire S ,
    output wire Co
);

assign Co = (A & B) | (A & Ci) | (B & Ci);
assign S  = ( A &  B &  Ci) | 
            ( A & ~B & ~Ci) |
            (~A &  B & ~Ci) |
            (~A & ~B &  Ci);

          
endmodule //full_adder_1