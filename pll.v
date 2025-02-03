/**
 * PLL configuration
 *
 * This Verilog module was generated using the icepll tool
 * and is configured for:
 * - Input Frequency:  12.000 MHz
 * - Output Frequency: 24.000 MHz
 */

module pll(
    input  clock_in,   // Input clock (12 MHz)
    output clock_out,  // Output clock (24 MHz)
    output locked      // PLL lock status
    );

SB_PLL40_PAD #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),        // DIVR =  0
    .DIVF(7'b0111111),     // DIVF = 63
    .DIVQ(3'b101),         // DIVQ =  5
    .FILTER_RANGE(3'b001)  // FILTER_RANGE = 1
) uut (
    .LOCK(locked),          // Output: PLL locked status
    .RESETB(1'b1),          // Input: Active-low reset
    .BYPASS(1'b0),          // Input: PLL bypass (disabled)
    .PACKAGEPIN(clock_in),  // Input: Directly from package pin (ext_clock)
    .PLLOUTCORE(clock_out)  // Output: 24 MHz clock
    );

endmodule
