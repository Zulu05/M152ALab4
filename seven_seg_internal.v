module seven_seg_internal (
    input  wire       clk_1khz,
    input  wire       rst,
    input  wire [4:0] left_val,   // P2 total (0 to 31)
    input  wire [4:0] right_val,  // P1 total (0 to 31)
    output reg  [6:0] seg,        // Active-low segments: {g, f, e, d, c, b, a}
    output reg  [3:0] an          // Active-low digit enables: AN3..AN0
);

    reg [1:0] digit_sel;
    reg [3:0] bcd_digit;

    // Extract tens and ones digits for both players
    wire [3:0] left_tens  = left_val / 5'd10;
    wire [3:0] left_ones  = left_val % 5'd10;
    wire [3:0] right_tens = right_val / 5'd10;
    wire [3:0] right_ones = right_val % 5'd10;

    // Cycle through the 4 digits at 1kHz
    always @(posedge clk_1khz or posedge rst) begin
        if (rst) begin
            digit_sel <= 2'd0;
        end else begin
            digit_sel <= digit_sel + 2'd1;
        end
    end

    // Select active anode and corresponding BCD value
    always @(*) begin
        case (digit_sel)
            2'd0: begin
                an        = 4'b1110; // AN0 (Rightmost: P1 Ones)
                bcd_digit = right_ones;
            end
            2'd1: begin
                an        = 4'b1101; // AN1 (P1 Tens)
                bcd_digit = right_tens;
            end
            2'd2: begin
                an        = 4'b1011; // AN2 (P2 Ones)
                bcd_digit = left_ones;
            end
            2'd3: begin
                an        = 4'b0111; // AN3 (Leftmost: P2 Tens)
                bcd_digit = left_tens;
            end
        endcase
    end

    // BCD to Active-Low 7-Segment Decoder (gfedcba)
    always @(*) begin
        case (bcd_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // Blank
        endcase
    end

endmodule
