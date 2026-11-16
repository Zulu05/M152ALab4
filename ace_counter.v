module ace_counter (
    input  wire [3:0] LEDs,  // 1/0 for high/low of LEDs right to left
    input  wire [3:0] sw,    // Switches (0 = rightmost)
    output wire [5:0] total  // 4 aces * 11 = 44 max
);

    // Check each bit: if LED is on, add 11 (if switch is on) or 1 (if switch is off)
    wire [5:0] val0 = LEDs[0] ? (sw[0] ? 6'd11 : 6'd1) : 6'd0;
    wire [5:0] val1 = LEDs[1] ? (sw[1] ? 6'd11 : 6'd1) : 6'd0;
    wire [5:0] val2 = LEDs[2] ? (sw[2] ? 6'd11 : 6'd1) : 6'd0;
    wire [5:0] val3 = LEDs[3] ? (sw[3] ? 6'd11 : 6'd1) : 6'd0;

    assign total = val0 + val1 + val2 + val3;

endmodule
