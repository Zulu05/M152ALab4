`timescale 1ns / 1ps

module seven_seg_internal #(
    parameter integer CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       clk_1khz,
    input  wire       rst,
    input  wire [4:0] left_val,        // P2 total (or card 1 on first draw)
    input  wire [4:0] right_val,       // P1 total (or card 2 on first draw)
    input  wire       first_draw_view, // Show both cards as 01..13 when 1
    input  wire       show_left,
    input  wire       show_right,
    input  wire       blank_all,
    input  wire       flash_left,
    input  wire       flash_right,
    output reg  [6:0] seg,             // Active-low {g, f, e, d, c, b, a}
    output reg  [3:0] an               // Active-low AN3..AN0
);

    localparam [3:0] BLANK = 4'd15;
    localparam integer BLINK_HALF_PERIOD = CLK_FREQ / 4; // ~2 Hz blink

    reg [26:0] blink_cnt;
    reg        blink_on;

    reg [1:0]  digit_sel;
    reg [3:0]  bcd_digit;
    reg        digit_en;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            blink_cnt <= 27'd0;
            blink_on  <= 1'b1;
        end else if (blink_cnt >= BLINK_HALF_PERIOD - 1) begin
            blink_cnt <= 27'd0;
            blink_on  <= ~blink_on;
        end else begin
            blink_cnt <= blink_cnt + 27'd1;
        end
    end

    wire [3:0] left_tens  = first_draw_view ? (left_val / 5'd10)  : (left_val / 5'd10);
    wire [3:0] left_ones  = first_draw_view ? (left_val % 5'd10)  : (left_val % 5'd10);
    wire [3:0] right_tens = first_draw_view ? (right_val / 5'd10) : (right_val / 5'd10);
    wire [3:0] right_ones = first_draw_view ? (right_val % 5'd10) : (right_val % 5'd10);

    wire left_visible  = !blank_all && show_left  && (!flash_left  || blink_on);
    wire right_visible = !blank_all && show_right && (!flash_right || blink_on);

    always @(posedge clk_1khz or posedge rst) begin
        if (rst) begin
            digit_sel <= 2'd0;
        end else begin
            digit_sel <= digit_sel + 2'd1;
        end
    end

    always @(*) begin
        an        = 4'b1111;
        bcd_digit = BLANK;
        digit_en  = 1'b0;

        case (digit_sel)
            2'd0: begin
                digit_en  = right_visible;
                an        = digit_en ? 4'b1110 : 4'b1111;
                bcd_digit = digit_en ? right_ones : BLANK;
            end
            2'd1: begin
                digit_en  = right_visible;
                an        = digit_en ? 4'b1101 : 4'b1111;
                bcd_digit = digit_en ? right_tens : BLANK;
            end
            2'd2: begin
                digit_en  = left_visible;
                an        = digit_en ? 4'b1011 : 4'b1111;
                bcd_digit = digit_en ? left_ones : BLANK;
            end
            2'd3: begin
                digit_en  = left_visible;
                an        = digit_en ? 4'b0111 : 4'b1111;
                bcd_digit = digit_en ? left_tens : BLANK;
            end
        endcase
    end

    always @(*) begin
        case (bcd_digit)
            4'd0:    seg = 7'b1000000;
            4'd1:    seg = 7'b1111001;
            4'd2:    seg = 7'b0100100;
            4'd3:    seg = 7'b0110000;
            4'd4:    seg = 7'b0011001;
            4'd5:    seg = 7'b0010010;
            4'd6:    seg = 7'b0000010;
            4'd7:    seg = 7'b1111000;
            4'd8:    seg = 7'b0000000;
            4'd9:    seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end

endmodule
