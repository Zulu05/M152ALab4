module pwm_audio #(
    parameter integer CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] sound_code,
    input  wire       sound_trig,
    output reg        audio_out
);

    localparam [1:0] SND_NONE     = 2'b00,
                     SND_P1_END   = 2'b01,
                     SND_GAME_END = 2'b10;

    localparam integer HALF_C5 = CLK_FREQ / (2 * 523);
    localparam integer HALF_E5 = CLK_FREQ / (2 * 659);
    localparam integer HALF_G5 = CLK_FREQ / (2 * 784);
    localparam integer HALF_A5 = CLK_FREQ / (2 * 880);

    localparam integer DUR_150MS = (CLK_FREQ * 3) / 20;
    localparam integer DUR_200MS = CLK_FREQ / 5;
    localparam integer DUR_300MS = (CLK_FREQ * 3) / 10;

    reg [1:0]  active_sound;
    reg [26:0] dur_counter;
    reg [1:0]  note_step;
    reg [18:0] tone_counter;
    reg [18:0] current_half_period;
    reg        playing;

    always @(posedge clk) begin
        if (rst) begin
            active_sound        <= SND_NONE;
            dur_counter         <= 27'd0;
            note_step           <= 2'd0;
            tone_counter        <= 19'd0;
            current_half_period <= 19'd0;
            playing             <= 1'b0;
            audio_out           <= 1'b0;
        end else begin
            if (sound_trig && (sound_code != SND_NONE)) begin
                active_sound <= sound_code;
                playing      <= 1'b1;
                note_step    <= 2'd0;
                dur_counter  <= 27'd0;
                tone_counter <= 19'd0;
            end else if (playing) begin
                case (active_sound)
                    // 1 beep when Player 1 ends turn
                    SND_P1_END: begin
                        current_half_period <= HALF_A5;
                        if (dur_counter >= DUR_200MS) begin
                            playing <= 1'b0;
                        end else begin
                            dur_counter <= dur_counter + 27'd1;
                        end
                    end

                    // Distinct 3-note chime when game ends
                    SND_GAME_END: begin
                        case (note_step)
                            2'd0: begin
                                current_half_period <= HALF_C5;
                                if (dur_counter >= DUR_150MS) begin
                                    dur_counter <= 27'd0;
                                    note_step   <= 2'd1;
                                end else dur_counter <= dur_counter + 27'd1;
                            end
                            2'd1: begin
                                current_half_period <= HALF_E5;
                                if (dur_counter >= DUR_150MS) begin
                                    dur_counter <= 27'd0;
                                    note_step   <= 2'd2;
                                end else dur_counter <= dur_counter + 27'd1;
                            end
                            2'd2: begin
                                current_half_period <= HALF_G5;
                                if (dur_counter >= DUR_300MS) begin
                                    playing <= 1'b0;
                                end else dur_counter <= dur_counter + 27'd1;
                            end
                            default: playing <= 1'b0;
                        endcase
                    end

                    default: playing <= 1'b0;
                endcase
            end

            if (playing && (current_half_period > 0)) begin
                if (tone_counter >= current_half_period - 1) begin
                    tone_counter <= 19'd0;
                    audio_out    <= ~audio_out;
                end else begin
                    tone_counter <= tone_counter + 19'd1;
                end
            end else begin
                tone_counter <= 19'd0;
                audio_out    <= 1'b0;
            end
        end
    end

endmodule
