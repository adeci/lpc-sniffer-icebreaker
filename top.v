module top #(parameter CLOCK_FREQ = 24_000_000, parameter BAUD_RATE = 2000000)
(
	input [3:0] lpc_ad,            // LPC data lines
	input lpc_clock,               // LPC clock 24MHz
	input lpc_frame,               // LPC frame signal
	input lpc_reset,               // LPC reset signal
	input ext_clock,               // External 12MHz clock source (on the icebreaker board)
	input fscts,                   // UART CTS
	input fsdo,                    // UART TX output
	output fsdi,                   // UART RX input
//	output fsclk,                  // UART clock
	output lpc_clock_led,          // LED for LPC clock
	output lpc_frame_led,          // LED for LPC frame
	output lpc_reset_led,          // LED for LPC reset
	output valid_lpc_output_led,   // LED for valid LPC output
	output overflow_led            // LED for overflow
);

	/* power on reset */
	wire reset;

	/* buffering */
	wire [3:0] lpc_ad;

	/* lpc */
	wire [3:0] dec_cyctype_dir;
	wire [31:0] dec_addr;
	wire [7:0] dec_data;
	wire dec_sync_timeout;

	/* bufferdomain*/
	wire [47:0] lpc_data;
	wire [47:0] write_data;
	wire lpc_data_enable;

	/* ring buffer */
	wire read_clock_enable;
	wire write_clock_enable;
	wire empty;
	wire overflow;

	/* mem2serial */
	wire [47:0] read_data;

	/* uart tx */
	wire uart_ready;
	wire [7:0] uart_data;
	wire uart_clock_enable;
	wire uart_clock;

	wire trigger_port;
	wire no_lpc_reset;

	wire main_clock;
	wire pll_locked;

	wire fsclk;
	assign fsclk = ext_clock;

	pll PLL(.clock_in(ext_clock),   // 12MHz clock input
		.clock_out(main_clock), // PLL output clock
		.locked(pll_locked)     // PLL lock status
	);

	power_on_reset POR(
		.pll_locked(pll_locked),
		.clock(main_clock),
		.reset(reset)
	);

	lpc LPC(
		.lpc_ad(lpc_ad),
		.lpc_clock(lpc_clock),
		.lpc_frame(lpc_frame),
		.lpc_reset(no_lpc_reset),
		.reset(reset),
		.out_cyctype_dir(dec_cyctype_dir),
		.out_addr(dec_addr),
		.out_data(dec_data),
		.out_sync_timeout(dec_sync_timeout),
		.out_clock_enable(lpc_data_enable)
	);

	bufferdomain #(.AW(48)) BUFFERDOMAIN(
		.input_data(lpc_data),
		.input_enable(lpc_data_enable),
		.reset(reset),
		.clock(main_clock),
		.output_data(write_data),
		.output_enable(write_clock_enable)
	);

	assign lpc_data[47:16] = dec_addr;
	assign lpc_data[15:8] = dec_data;
	assign lpc_data[7:5] = 0;
	assign lpc_data[4] = dec_sync_timeout;
	assign lpc_data[3:0] = dec_cyctype_dir;

	ringbuffer #(.AW(10), .DW(48)) RINGBUFFER (
		.reset(reset),
		.clock(main_clock),
		.write_clock_enable(write_clock_enable),
		.read_clock_enable(read_clock_enable),
		.read_data(read_data),
		.write_data(write_data),
		.empty(empty),
		.overflow(overflow)
	);

	mem2serial MEM_SERIAL(
		.reset(reset),
		.clock(main_clock),
		.read_empty(empty),
		.read_clock_enable(read_clock_enable),
		.read_data(read_data),
		.uart_clock_enable(uart_clock_enable),
		.uart_ready(uart_ready),
		.uart_data(uart_data)
	);

	wire [1:0] state;
	ftdi SERIAL (
		.read_data(uart_data),
		.read_clock_enable(uart_clock_enable),
		.reset(reset),
		.ready(uart_ready),
		.fsdi(fsdi),
		.fscts(fscts),
		.state(state),
		.clock(main_clock)
	);

	trigger_led TRIGGERLPC(
		.reset(reset),
		.clock(main_clock),
		.led(valid_lpc_output_led),
		.trigger(trigger_port)
	);

	//assign trigger_port = dec_addr == 32'h80 && dec_data == 8'h34 && dec_cyctype_dir == 4'b0010;
	//assign trigger_port = dec_addr == 32'h3f9 && dec_cyctype_dir == 4'b0100;
	assign trigger_port = dec_cyctype_dir == 4'b0100;

	/* LED for LPC Clock Blinking */
	reg [23:0] clock_divider = 0; // 24-bit counter for division
	reg lpc_clock_blink = 0;      // Register to hold the blinking state

	always @(posedge lpc_clock or negedge reset) begin
		if (!reset) begin
			clock_divider <= 0;
			lpc_clock_blink <= 0;
		end else begin
			clock_divider <= clock_divider + 1;
			if (clock_divider == CLOCK_FREQ / 2) begin // ~1 Hz blink rate
				lpc_clock_blink <= ~lpc_clock_blink;
				clock_divider <= 0;
			end
		end
	end

	assign lpc_clock_led = lpc_clock_blink;
	assign lpc_frame_led = 0;
	assign lpc_reset_led = 1;
	assign no_lpc_reset = 1;
	assign overflow_led = overflow;

endmodule
