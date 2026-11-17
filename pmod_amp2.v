module pmod_amp2_tone #(
    parameter CLK_FREQ  = 100_000_000, // 100 MHz FPGA clock (e.g., Basys 3 / Arty)
    parameter TONE_FREQ = 440          // 440 Hz (A4 note)
)(
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  pmod_ain,      // Pmod Pin 1
    output wire pmod_gain,     // Pmod Pin 2
    output wire pmod_shutdown  // Pmod Pin 4
);

    // Enable amplifier (active-low shutdown) and set lower gain (6 dB)
    assign pmod_shutdown = enable; 
    assign pmod_gain     = 1'b1;   

    // Calculate half-period clock cycles to toggle the square wave
    localparam integer HALF_PERIOD = CLK_FREQ / (TONE_FREQ * 2);
    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst || !enable) begin
            counter  <= 32'd0;
            pmod_ain <= 1'b0;
        end else begin
            if (counter >= HALF_PERIOD - 1) begin
                counter  <= 32'd0;
                pmod_ain <= ~pmod_ain; // Toggle output to create square wave
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule
