`timescale 1ns / 1ps

module seven_seg_pmod (
    input  wire       clk_1khz,
    input  wire       rst,
    input  wire [3:0] card_val,
    input  wire       blank,
    output reg  [6:0] pmod_seg, // {g, f, e, d, c, b, a}, active-high
    output reg        pmod_cat  // 0 = right digit, 1 = left digit
);

    localparam [3:0] BLANK = 4'd15;

    reg [3:0] left_digit;
    reg [3:0] right_digit;
    reg [3:0] active_digit;

    always @(*) begin
        if (blank || card_val == 4'd0 || card_val > 4'd13) begin
            left_digit  = BLANK;
            right_digit = BLANK;
        end else if (card_val < 4'd10) begin
            left_digit  = 4'd0;
            right_digit = card_val;
        end else begin
            left_digit  = 4'd1;
            right_digit = card_val - 4'd10;
        end
    end

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
            default: pmod_seg = 7'b0000000;
        endcase
    end

endmodule
