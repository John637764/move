module cache(
    input  wire 	   clk    ,
    input  wire 	   reset  ,
    // Cache与CPU流水线的交互接口
	input  wire [ 2:0] c        ,   //cache属性
	input  wire 	   valid    ,   //表明请求有效
    input  wire 	   op       ,   //1：write  0：read
    input  wire [ 7:0] index    ,   //addr[11: 4]
    input  wire [19:0] tag      ,   //addr[31:12]
    input  wire [ 3:0] offset   ,   //addr[ 3: 0]
    input  wire [ 3:0] wstrb    ,   //字节写使能
    input  wire [31:0] wdata    ,   //写入数据
    output wire        addr_ok  ,   //该次请求的地址传输OK，读：地址被接收； 写：地址和数据被接收
    output wire        data_ok  ,   //该次请求的数据传输OK，读：数据返回；   写：数据写入完成
    output wire [31:0] rdata    ,   //读Cache的结果
	//Cache与sram接口的交互接口
    output wire        rd_req 	,   //读请求有效信号，高电平有效
    output wire [ 2:0] rd_type	,   //读请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    output wire [31:0] rd_addr	,   //读请求起始地址
    input  wire        rd_rdy 	,   //读请求能否被接收的握手信号，高电平有效
    input  wire        ret_valid,   //返回数据有效信号，高电平有效
    input  wire 	   ret_last ,   //返回数据是1次读请求对应的最后1个返回数据
    input  wire [31:0] ret_data ,   //读返回数据

    output wire        wr_req   ,   //写请求有效信号，高电平有效
    output wire [ 2:0] wr_type  ,   //写请求类型。3'b000：字节，3'b001：半字 3'b010：字，3'b100：Cache行
    output wire [31:0] wr_addr  ,   //写请求起始地址
    output wire [ 3:0] wr_wstrb ,   //写操作的字节掩码，仅在写请求类型不为Cache行的情况下才有意义
    output wire [127:0]wr_data  ,   //写数据
    input  wire        wr_rdy   ,   //写请求能否被接收的握手信号，高电平有效
	input  wire        wr_wvalid,   //uncached的写请求响应
	input  wire        wr_wlast     //uncached的写请求响应
);

wire 	    bank_ena  [7:0];
wire [ 3:0] bank_wea  [7:0];
wire [ 7:0] bank_addr [7:0];
wire [31:0] bank_dina [7:0];

wire 	    tagv_ena  [1:0];
wire 	    tagv_wea  [1:0];
wire [ 7:0] tagv_addr [1:0];
wire [20:0] tagv_dina [1:0];

wire 	    dirty_wea  [1:0];
wire [ 7:0] dirty_addr [1:0];
wire 	    dirty_din  [1:0];
wire        dirty_dout [1:0];

wire cached;
assign cached = c == 3'h3;
//wire busy;   //新的访问与hit write冲突
//main state machine
reg  [2:0] m_prestate;
wire [2:0] m_nexstate;
parameter MIDLE  = 3'd0;
parameter LOOKUP = 3'd1;
parameter MISS   = 3'd2;
parameter REPLACE= 3'd3;
parameter REFILL = 3'd4;
always @(posedge clk)begin
	if(reset)
		m_prestate <= MIDLE;
	else
		m_prestate <= m_nexstate;
end

//hit wirte state machine
reg  h_prestate;
wire h_nexstate;
parameter HIDLE = 1'b0;
parameter WRITE = 1'b1;
always @(posedge clk)begin
	if(reset)
		h_prestate <= HIDLE;
	else
		h_prestate <= h_nexstate;
end

//request_buffer
reg  [69:0]	request_buffer;
wire        cached_r;
wire        op_r    ;
wire [ 7:0] index_r ;
wire [19:0] tag_r   ;
wire [ 3:0] offset_r;
wire [ 3:0] wstrb_r ;  
wire [31:0] wdata_r ;  
always @(posedge clk) begin
	if(reset)
		request_buffer <= 70'b0;
	else if(m_nexstate == LOOKUP)
		request_buffer <= {cached,op,index,tag,offset,wstrb,wdata};
end
assign {cached_r,op_r,index_r,tag_r,offset_r,wstrb_r,wdata_r} = request_buffer; 

//tag compare
wire [ 1:0] way_hit      ;
wire [ 1:0] way_v        ;
wire [19:0] way_tag [1:0];
wire cache_hit;

assign way_hit[0] = way_v[0] & (way_tag[0] == tag_r);
assign way_hit[1] = way_v[1] & (way_tag[1] == tag_r);
assign cache_hit  = (|way_hit) & cached_r; 

//data select
wire [31:0] axi_rdata;
wire [31:0] bank_rdata [7:0];
wire [31:0] way_rdata  [1:0];
assign way_rdata[0] = bank_rdata[offset_r[3:2]]  ;
assign way_rdata[1] = bank_rdata[offset_r[3:2]+4];
assign rdata              = {32{way_hit[0]}} & way_rdata[0] & {32{m_prestate == LOOKUP}}
						   |{32{way_hit[1]}} & way_rdata[1] & {32{m_prestate == LOOKUP}}
						   |{32{m_prestate == REFILL && m_nexstate == MIDLE}} & axi_rdata;
						   
//LFSR
wire replace_way;
reg D1,D2,D3,D4;
assign replace_way = D1;

always @(posedge clk) begin 
	if(reset)
		D1 <= 1'b1;
	else
		D1 <= D1 ^ D4;
end
always @(posedge clk) begin
	if(reset)
		D2 <= 1'b0;
	else
		D2 <= D1;
end
always @(posedge clk) begin
	if(reset)
		D3 <= 1'b1;
	else
		D3 <= D2;
end
always @(posedge clk) begin
	if(reset)
		D4 <= 1'b0;
	else
		D4 <= D3;
end
//miss buffer
wire [127:0] replace_data [1:0];
assign replace_data[1] = {bank_rdata[7],bank_rdata[6],bank_rdata[5],bank_rdata[4]};
assign replace_data[0] = {bank_rdata[3],bank_rdata[2],bank_rdata[1],bank_rdata[0]};
reg  [150:0] miss_buff;
wire [127:0] mbuff_replace_data;
wire         mbuff_replace_way;
wire [ 19:0] mbuff_tag_r;
wire         mbuff_v_r;
wire         mbuff_dirty_r;
always @(posedge clk) begin
	if(m_prestate == MISS && m_nexstate == REPLACE) begin
		if(replace_way)
			miss_buff <= {way_tag[1],way_v[1],dirty_dout[1],replace_way,replace_data[1]};
		else
			miss_buff <= {way_tag[0],way_v[0],dirty_dout[0],replace_way,replace_data[0]};
	end
end
assign {mbuff_tag_r,mbuff_v_r,mbuff_dirty_r,mbuff_replace_way,mbuff_replace_data} = miss_buff;

wire [127:0] rev_data;
reg  [ 95:0] rev_buff;
reg  [  1:0] rev_cnt;
assign rev_data = {ret_data,rev_buff};
always @(posedge clk) begin
	if(m_nexstate == REFILL) begin
		if(ret_valid) begin
			case (rev_cnt)
				2'd0 : rev_buff[ 31: 0] <= ret_data;
				2'd1 : rev_buff[ 63:32] <= ret_data;
				2'd2 : rev_buff[ 95:64] <= ret_data;
				default: rev_buff <= rev_buff;
			endcase
		end
	end
end

always @(posedge clk) begin
	if(reset || rev_cnt == 2'd3)
		rev_cnt <= 2'd0;
	else if(m_nexstate == REFILL) begin
		if(ret_valid)
			rev_cnt <= rev_cnt + 1;
	end
end

assign axi_rdata = cached_r ? rev_data[offset_r[3:2]*32 +:32] : ret_data;

reg  [49:0] write_buff;
wire [ 7:0] w_index_r;
wire [ 3:0] w_offset_r;
wire [ 3:0] w_wstrb_r;
wire [31:0] w_wdata_r;
wire 	    w_wayhit_r;
always @(posedge clk) begin
	if(h_nexstate == WRITE)
		write_buff <= {way_hit[1],index_r,offset_r,wstrb_r,wdata_r};
end
assign {w_wayhit_r,w_index_r,w_offset_r,w_wstrb_r,w_wdata_r} = write_buff;

genvar i;
generate 
	for(i=0;i<8;i=i+1) begin
	:BANK_ENA
		assign bank_ena[i] = m_nexstate == LOOKUP && cached 										 || 
							 m_prestate == MISS   && cached_r										 || 
							 m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i/4 
							 && cached_r															 ||
							 h_prestate == WRITE  && {w_wayhit_r,w_offset_r[3:2]} == i;
	end
	
	for(i=0;i<8;i=i+1) begin
	:BANK_WEA
		assign bank_wea[i] = h_prestate == WRITE  && {w_wayhit_r,w_offset_r[3:2]} == i ? w_wstrb_r :
							 cached_r && m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i/4 ? 4'hf : 4'b0;
	end
	
	for(i=0;i<4;i=i+1) begin
	:BANK_DINA1	
		assign bank_dina[i] = h_prestate == WRITE 		 ? w_wdata_r : 
							  offset_r[3:2] == i && op_r ? wdata_r   :
														   rev_data[i*32+:32];
																				
	end

	for(i=4;i<8;i=i+1) begin
	:BANK_DINA2
		assign bank_dina[i] = h_prestate == WRITE   	   ? w_wdata_r : 
							  offset_r[3:2] == i-4 && op_r ? wdata_r   :
															 rev_data[(i-4)*32+:32];
																				
	end
	
	for(i=0;i<8;i=i+1) begin
	:BANK_ADDR
		assign bank_addr[i] = h_prestate == WRITE && {w_wayhit_r,w_offset_r[3:2]} == i ? w_index_r : 
							  m_nexstate == LOOKUP                                     ? index     :
			  /*m_prestate == MISS || m_prestate == REFILL && m_nexstate == MIDLE ?*/    index_r   ;
	end

	for(i=0;i<8;i=i+1) begin
	:DATA_BANK
		DATA_BANK bank (
			.clka(clk)         ,  // input  wire clka
			.ena(bank_ena[i])	 ,  // input  wire ena
			.wea(bank_wea[i])	 ,  // input  wire [3 : 0] wea
			.addra(bank_addr[i]) ,  // input  wire [7 : 0] addra
			.dina(bank_dina[i])  ,  // input  wire [31 : 0] dina
			.douta(bank_rdata[i])   // output wire [31 : 0] douta
		);
	end

	for(i=0;i<2;i=i+1) begin
	:TAGV_ENA
		assign tagv_ena[i] = m_nexstate == LOOKUP && cached										   || 
							 m_prestate == MISS   && cached_r									   ||
							 cached_r && m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i ;
	end

	for(i=0;i<2;i=i+1) begin
	:TAGV_WEA
		assign tagv_wea[i] = cached_r && m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i;
	end

	for(i=0;i<2;i=i+1) begin
	:TAGV_ADDR
		assign tagv_addr[i] = m_nexstate == LOOKUP ? index   :
						  /*m_prestate == MISS   ?*/ index_r ;
													 
	end

	for(i=0;i<2;i=i+1) begin
	:TAGV_DINA
		assign tagv_dina[i] = {tag_r,1'b1};
	end

	for(i=0;i<2;i=i+1) begin
	:TAGV
		TAGV tagv (
			.clka(clk)         	 	 ,     // input wire clka
			.ena(tagv_ena[i])		 ,     // input wire ena
			.wea(tagv_wea[i])		 ,     // input wire [0 : 0] wea
			.addra(tagv_addr[i])	 ,     // input wire [7 : 0] addra
			.dina(tagv_dina[i]) 	 ,     // input wire [20 : 0] dina
			.douta({way_tag[i],way_v[i]})  // output wire [20 : 0] douta
		);
	end

	for(i=0;i<2;i=i+1) begin
	:DIRTY_WEA
		assign dirty_wea[i] = h_prestate == WRITE  && w_wayhit_r == i     ||
							  cached_r && m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i;
	end

	for(i=0;i<2;i=i+1) begin
	:DIRTY_ADDR
		assign dirty_addr[i] = h_prestate == WRITE ? w_index_r :
						   
						   /*m_prestate == MISS  ?*/ index_r   ; 
	end
	
	for(i=0;i<2;i=i+1) begin
	:DIRTY_DIN
		assign dirty_din[i] = h_prestate == WRITE                                                           ||
							  m_prestate == REFILL && m_nexstate == MIDLE && mbuff_replace_way == i && op_r;
	end

	for(i=0;i<2;i=i+1) begin
	:DIRTY
		regfile_dirty dirty0 (
			.clk    (clk  		  ),
			.reset  (reset		  ),
			.wen    (dirty_wea [i]),
			.addr   (dirty_addr[i]),
			.din    (dirty_din [i]),
			.dout   (dirty_dout[i])
		);
	end
endgenerate

assign addr_ok  = m_nexstate == LOOKUP;
assign data_ok  = m_prestate == LOOKUP && cache_hit ||  
				  m_prestate == LOOKUP && op_r      ||
				  m_prestate == REFILL && m_nexstate == MIDLE && !op_r;
assign rd_type  = !cached_r ? 3'b010 : 3'b100;
assign rd_addr  = {tag_r,index_r,!cached_r ? offset_r : 4'h0};
assign wr_type  = !cached_r ? 3'b010 : 3'b100;
assign wr_addr  = {!cached_r ? tag_r : mbuff_tag_r,index_r,!cached_r ? offset_r : 4'h0};
assign wr_wstrb = !cached_r ? wstrb_r : 4'hf;
assign wr_data  = !cached_r ? {4{wdata_r}} : mbuff_replace_data;
assign wr_req   = m_prestate == REPLACE && (mbuff_dirty_r || !cached_r && op_r); 
assign rd_req   = m_prestate == REPLACE && !(!cached_r && op_r);

//main state machine
assign m_nexstate = m_prestate == MIDLE ?
					(
						valid && !(h_prestate == WRITE && !op && offset[3:2] == w_offset_r[3:2]) ? LOOKUP : MIDLE
					):
					m_prestate == LOOKUP ?
					(
						!cache_hit     															  ? MISS :
						valid && !(op_r && !op && {tag,index,offset} == {tag_r,index_r,offset_r}) ? LOOKUP : MIDLE
					):
					m_prestate == MISS ?
					(
						wr_rdy ? REPLACE : MISS
					):
					m_prestate == REPLACE ?
					(
						rd_rdy ? REFILL : REPLACE
					):
					m_prestate == REFILL ?
					(
						!cached_r && (wr_wvalid && wr_wlast && op_r || ret_last && ret_valid && !op_r) ? MIDLE :
						 cached_r &&  ret_valid && ret_last 						  				   ? MIDLE : REFILL
					):
					m_prestate;
//hit wirte state machine
assign h_nexstate = h_prestate == HIDLE ?
					(
						m_prestate == LOOKUP && cache_hit && op_r ? WRITE : HIDLE
					):
					h_prestate == WRITE ?
					(
						m_prestate == LOOKUP && cache_hit && op_r ? WRITE : HIDLE
					):
					h_prestate;

endmodule