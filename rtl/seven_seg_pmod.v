`timescale 1ns / 1ps

module seven_seg_pmod (
    input  wire       clk_1khz,
    input  wire       rst,
    input  wire [3:0] card_val,
    output reg  [6:0] pmod_seg, // {G, F, E, D, C, B, A}, active-high
    output reg        pmod_cat  // 0 = right digit, 1 = left digit
);

    // Special nibble code for blank digit
    localparam [3:0] BLANK = 4'd15;

    reg [3:0] left_digit;
    reg [3:0] right_digit;
    reg [3:0] active_digit;

    // Decode card_val (0 = blank, 1..13 = 01..13) into left and right digits
    always @(*) begin
        if (card_val == 4'd0 || card_val > 4'd13) begin
            left_digit  = BLANK;
            right_digit = BLANK;
        end else if (card_val < 4'd10) begin
            left_digit  = 4'd0;
            right_digit = card_val;
        end else begin
            // 10, 11 (J), 12 (Q), 13 (K) rendered as digits 10..13
            left_digit  = 4'd1;
            right_digit = card_val - 4'd10;
        end
    end

    // Alternate digits on clk_1khz (500 Hz per digit -> flicker-free)
    always @(posedge clk_1khz or posedge rst) begin
        if (rst) begin
            pmod_cat <= 1'b0;
        end else begin
            pmod_cat <= ~pmod_cat;
        end
    end

    always @(*) begin
        active_digit = pmod_cat ? left_digit : right_digit;
    end

    // Active-high 7-segment decoder: pmod_seg = {g, f, e, d, c, b, a}
    always @(*) begin
        case (active_digit)
            4'd0:    pmod_seg = 7'b0111111;
            4'd1:    pmod_seg = 7'b0000110;
            4'd2:    pmod_seg = 7'b1011011;
            4'd3:    pmod_seg = 7'b1001111;
            4'd4:    pmod_seg = 7'b1100110;
            4'd5:    pmod_seg = 7'b1101101;
            4'd6:    pmod_seg = 7'b1111101;
            4'd7:    pmod_seg = 7'b0000111;
            4'd8:    pmod_seg = 7'b1111111;
            4'd9:    pmod_seg = 7'b1101111;
            default: pmod_seg = 7'b0000000; // Blank
        endcase
    end

endmodule
