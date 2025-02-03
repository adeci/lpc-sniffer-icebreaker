NAME = top
DEPS = buffer.v bufferdomain.v lpc.v mem2serial.v ringbuffer.v power_on_reset.v trigger_led.v pll.v ftdi.v
PCF = $(NAME).pcf
JSON = $(NAME).json
ASC = $(NAME).asc
BIN = $(NAME).bin

# Toolchain binaries
YOSYS = yosys
NEXTPNR = nextpnr-ice40
ICEPACK = icepack
ICEPROG = iceprog
IVERILOG = iverilog

# FPGA parameters
DEVICE = up5k
PACKAGE = sg48
FREQ = 24

# Default target: build and generate the bitstream
all: $(BIN)

# Synthesis: Convert Verilog to JSON (intermediate representation)
$(JSON): $(NAME).v $(DEPS)
	$(YOSYS) -p "synth_ice40 -top $(NAME) -json $(JSON)" $(NAME).v $(DEPS)

# Place and Route: Generate ASCII representation of the FPGA configuration
$(ASC): $(JSON) $(PCF)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --pcf $(PCF) --json $(JSON) --asc $(ASC) --freq $(FREQ)

# Bitstream generation: Convert ASCII to binary for flashing
$(BIN): $(ASC)
	$(ICEPACK) $(ASC) $(BIN)
	cp $(BIN) lpc_sniffer.bin

# Flash to FPGA: Upload the binary to the iCEBreaker board
flash: $(BIN)
	$(ICEPROG) $(BIN)

# Testbenches: Compile and simulate
buffer.vvp: buffer_tb.v buffer.v
	$(IVERILOG) -o buffer_tb.vvp buffer_tb.v buffer.v

mem2serial.vvp: mem2serial_tb.v mem2serial.v
	$(IVERILOG) -o mem2serial_tb.vvp mem2serial_tb.v mem2serial.v

ringbuffer.vvp: ringbuffer_tb.v ringbuffer.v buffer.v
	$(IVERILOG) -o ringbuffer_tb.vvp ringbuffer_tb.v ringbuffer.v buffer.v

uart_tx_tb.vvp: uart_tx_tb.v uart_tx.v
	$(IVERILOG) -o uart_tx_tb.vvp uart_tx_tb.v uart_tx.v

top_tb.vvp: top_tb.v $(NAME).v $(DEPS) ./test/sb_pll40_core_sim.v
	$(IVERILOG) -o top_tb.vvp top_tb.v $(NAME).v $(DEPS) ./test/sb_pll40_core_sim.v

# Cleaning up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN) $(NAME).blif $(NAME).txt
	rm -f *.vvp

# Default test target
test: buffer.vvp mem2serial.vvp ringbuffer.vvp uart_tx_tb.vvp top_tb.vvp

# Install target for flashing
install: $(BIN)
	$(ICEPROG) $(BIN)

.PHONY: all clean flash install test

