`timescale 1ns / 1ps

module tb_ace_counter;

    // Inputs
    reg [3:0] LEDs;
    reg [3:0] sw;

    // Outputs
    wire [5:0] total;

    // Instantiate the Unit Under Test (UUT)
    ace_counter uut (
        .LEDs  (LEDs),
        .sw    (sw),
        .total (total)
    );

    initial begin
        // Monitor changes automatically
        $monitor("Time=%0t | LEDs=%b | sw=%b | total=%d", $time, LEDs, sw, total);

        // Test 1: No aces active (Expected: 0)
        LEDs = 4'b0000; sw = 4'b1111; #10;

        // Test 2: 1 ace active, switch off (Expected: 1)
        LEDs = 4'b0001; sw = 4'b0000; #10;

        // Test 3: 1 ace active, switch on (Expected: 11)
        LEDs = 4'b0001; sw = 4'b0001; #10;

        // Test 4: 2 aces active, one 11 and one 1 (Expected: 12)
        LEDs = 4'b0101; sw = 4'b0100; #10;

        // Test 5: 3 aces active, all worth 1 (Expected: 3)
        LEDs = 4'b1110; sw = 4'b0001; #10;

        // Test 6: All 4 aces active, all worth 11 (Expected: 44)
        LEDs = 4'b1111; sw = 4'b1111; #10;

        $finish;
    end

endmodule

// Example on how to use the module
// module blackjack_top (
//     input  wire       clk,
//     input  wire       rst,
//     input  wire [3:0] sw,
//     output reg  [3:0] LEDs
//     // ... other ports
// );

//     wire [5:0] ace_total; // Always holds the live total of active aces
//     reg  [5:0] hand_score;

//     // 1. Instantiate the ace_counter
//     ace_counter my_ace_counter (
//         .LEDs  (LEDs),
//         .sw    (sw),
//         .total (ace_total)
//     );

//     // 2. Read 'ace_total' whenever your main logic needs it
//     always @(posedge clk) begin
//         if (rst) begin
//             hand_score <= 6'd0;
//         end else begin
//             // Example: Add live ace value to non-ace cards at any time
//             hand_score <= base_card_total + ace_total;
//         end
//     end

// endmodule

