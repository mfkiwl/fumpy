module adder (
	input clk, rst_n,
	input RX,
	output TX, 
	output RX_debug, TX_debug
);

//parameter define
parameter  CLK_FREQ = 50000000;
parameter  UART_BPS = 9600;

wire rx_done_raw, rx_done; 	// raw signal lasts for many cycles
							// while the done sig only last for one cycle
wire tx_done;
logic send_data;
reg[7:0] rx_data;
logic[7:0] tx_data;

logic[3:0] op1_mux, op2_mux, result_mux;
logic calc;

wire[31:0] result_wire;
reg[31:0] op1, op2, result;


assign RX_debug = RX;
assign TX_debug = TX;


uart #(
	.CLK_FREQ(CLK_FREQ),
	.UART_BPS(UART_BPS)
)
myUART (
	//inputs
	.clk(clk),
	.rst_n(rst_n),
	.RX(RX),
	.send_data(send_data),
	.tx_data(tx_data),
	
	//outputs
	.TX(TX),
	.rx_done(rx_done_raw),
	.tx_done(tx_done),
	.rx_data(rx_data)
);

posedgeDect pd1 (
	.clk(clk),
	.rst_n(rst_n),
	.in(rx_done_raw),
	.out(rx_done)
);

/*
FP_add_sub myfpa (
	.aclr(!rst_n),
	.clock(clk),
	.dataa(op1),
	.datab(op2),
	.result(result_wire)
);
*/

FP_mult myfpm (
	.aclr(!rst_n),
	.clock(clk),
	.dataa(op1),
	.datab(op2),
	.result(result_wire)
);

// count 14 cycles for result
reg[3:0] count_14;
always_ff @ (posedge clk or negedge rst_n) begin
	if (!rst_n)
		count_14 <= 4'b0;
	else if (calc)
		count_14 <= count_14 + 1;
	else if (count_14 == 15)
		count_14 <= 4'b0;
	else if (count_14 > 0)
		count_14 <= count_14 + 1;
	else count_14 <= 4'b0;
end


always_ff @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		result <= 0;
	end else if (count_14 == 14) begin
		result <= result_wire;
	end else begin
		result <= result;
	end
end


typedef enum reg[3:0] {
		IDLE,
		f11, f12, f13, f14,	// rcv 1st operand
		f21, f22, f23, f24, // rcv 2nd operand
		CALC,				// calculate
		c1, c2, c3, c4 		// send back result
	} state_t;

state_t state, nxt_state;


always_ff @(posedge clk or negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;


always_ff @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		op1 <= 32'b0;
		op2 <= 32'b0;
	end else begin
		case (op1_mux) 
			4'd0: op1 <= op1;
			4'd1: op1 <= {rx_data,op1[23:0]};
			4'd2: op1 <= {op1[31:24],rx_data,op1[15:0]};
			4'd3: op1 <= {op1[31:16],rx_data,op1[7:0]};
			4'd4: op1 <= {op1[31:8],rx_data};
		endcase
		
		case (op2_mux) 
			4'd0: op2 <= op2;
			4'd1: op2 <= {rx_data,{op2[23:0]}};
			4'd2: op2 <= {op2[31:24],rx_data,op2[15:0]};
			4'd3: op2 <= {op2[31:16],rx_data,op2[7:0]};
			4'd4: op2 <= {op2[31:8],rx_data};
		endcase
	end
end


always_ff @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tx_data <= 8'b0;
	end else begin
		case (result_mux)
		4'd0: tx_data <= tx_data;
		4'd1: tx_data <= result[31:24];
		4'd2: tx_data <= result[23:16];
		4'd3: tx_data <= result[15:8];
		4'd4: tx_data <= result[7:0];
		default: ;
	endcase
	end
end


always_comb begin
	// default values:
	send_data = 1'b0;
	op1_mux = 3'd0;
	op2_mux = 3'd0;
	result_mux = 3'd0;
	calc = 1'b0;
	
	case (state)
	
		IDLE: begin
			if (rx_done) begin
				nxt_state = f11;
				op1_mux = 3'd1;
			end else begin
				nxt_state = IDLE;
			end
		end
		
		f11: begin
			if (rx_done) begin
				nxt_state = f12;
				op1_mux = 3'd2;
			end else begin
				nxt_state = f11;
			end
		end
		
		f12: begin
			if (rx_done) begin
				nxt_state = f13;
				op1_mux = 3'd3;
			end else begin
				nxt_state = f12;
			end
		end
		
		f13: begin
			if (rx_done) begin
				nxt_state = f14;
				op1_mux = 3'd4;
			end else begin
				nxt_state = f13;
			end
		end
		
		f14: begin
			if (rx_done) begin
				nxt_state = f21;
				op2_mux = 3'd1;
			end else begin
				nxt_state = f14;
			end
		end
		
		f21: begin
			if (rx_done) begin
				nxt_state = f22;
				op2_mux = 3'd2;
			end else begin
				nxt_state = f21;
			end
		end
		
		f22: begin
			if (rx_done) begin
				nxt_state = f23;
				op2_mux = 3'd3;
			end else begin
				nxt_state = f22;
			end
		end
		
		f23: begin
			if (rx_done) begin
				nxt_state = CALC;
				calc = 1'b1;
				op2_mux = 3'd4;
			end else begin
				nxt_state = f23;
			end
		end
		
		/*
		f24: begin
			if (1'b1) begin
				nxt_state = CALC;
				//op2_mux = 3'd4;
				calc = 1'b1;
			end else begin
				nxt_state = f24;
			end
		end
		*/
		
		CALC: begin
			if (count_14 == 15) begin
				nxt_state = c1;
				result_mux = 3'd1;
				send_data = 1'b1;
			end else begin
				nxt_state = CALC;
			end
		end
		
		c1: begin
			if (tx_done) begin
				nxt_state = c2;
				result_mux = 3'd2;
				send_data = 1'b1;
			end else begin
				nxt_state = c1;
			end
		end
		
		c2: begin
			if (tx_done) begin
				nxt_state = c3;
				result_mux = 3'd3;
				send_data = 1'b1;
			end else begin
				nxt_state = c2;
			end
		end
		
		c3: begin
			if (tx_done) begin
				nxt_state = c4;
				result_mux = 3'd4;
				send_data = 1'b1;
			end else begin
				nxt_state = c3;
			end
		end
		
		c4: begin
			if (tx_done) begin
				nxt_state = IDLE;
			end else begin
				nxt_state = c4;
			end
		end

	endcase
end

endmodule
