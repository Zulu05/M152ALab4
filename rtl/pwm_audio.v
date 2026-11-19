module pwm_audio #(
    parameter CLK_FREQ = 100_000_000 // Default 100 MHz system clock
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] sound_code,
    output reg        audio_out
);

    // Sound code encodings
    localparam SND_NONE = 2'b00;
    localparam SND_HIT  = 2'b01;
    localparam SND_WIN  = 2'b10;
    localparam SND_LOSE = 2'b11;

    // Half-period clock tick counts for musical notes (CLK_FREQ / (2 * Note_Freq))
    localparam HALF_C4 = CLK_FREQ / (2 * 262); // ~261.63 Hz
    localparam HALF_E4 = CLK_FREQ / (2 * 330); // ~329.63 Hz
    localparam HALF_C5 = CLK_FREQ / (2 * 523); // ~523.25 Hz
    localparam HALF_E5 = CLK_FREQ / (2 * 659); // ~659.25 Hz
    localparam HALF_G5 = CLK_FREQ / (2 * 784); // ~783.99 Hz
    localparam HALF_A5 = CLK_FREQ / (2 * 880); // ~880.00 Hz

    // Duration constants (in clock cycles)
    localparam DUR_100MS = CLK_FREQ / 10;
    localparam DUR_150MS = (CLK_FREQ * 3) / 20;
    localparam DUR_250MS = CLK_FREQ / 4;
    localparam DUR_300MS = (CLK_FREQ * 3) / 10;

    // Internal registers
    reg [1:0]  prev_sound;
    reg [1:0]  active_sound;
    reg [26:0] dur_counter;
    reg [1:0]  note_step;
    reg [18:0] tone_counter;
    reg [18:0] current_half_period;
    reg        playing;

    // Main playback and sequencing logic
    always @(posedge clk) begin
        if (rst) begin
            prev_sound          <= SND_NONE;
            active_sound        <= SND_NONE;
            dur_counter         <= 27'd0;
            note_step           <= 2'd0;
            tone_counter        <= 19'd0;
            current_half_period <= 19'd0;
            playing             <= 1'b0;
            audio_out           <= 1'b0;
        end else begin
            prev_sound <= sound_code;

            // 1. Trigger on any new non-zero sound_code transition
            if ((sound_code != prev_sound) && (sound_code != SND_NONE)) begin
                active_sound <= sound_code;
                playing      <= 1'b1;
                note_step    <= 2'd0;
                dur_counter  <= 27'd0;
                tone_counter <= 19'd0;
            end 
            // 2. Sequence notes while playing
            else if (playing) begin
                case (active_sound)
                    // Single short chirp for hitting / button press
                    SND_HIT: begin
                        current_half_period <= HALF_A5;
                        if (dur_counter >= DUR_100MS) begin
                            playing <= 1'b0;
                        end else begin
                            dur_counter <= dur_counter + 1'b1;
                        end
                    end

                    // Ascending 3-note arpeggio for winning
                    SND_WIN: begin
                        case (note_step)
                            2'd0: begin
                                current_half_period <= HALF_C5;
                                if (dur_counter >= DUR_150MS) begin
                                    dur_counter <= 27'd0;
                                    note_step   <= 2'd1;
                                end else dur_counter <= dur_counter + 1'b1;
                            end
                            2'd1: begin
                                current_half_period <= HALF_E5;
                                if (dur_counter >= DUR_150MS) begin
                                    dur_counter <= 27'd0;
                                    note_step   <= 2'd2;
                                end else dur_counter <= dur_counter + 1'b1;
                            end
                            2'd2: begin
                                current_half_period <= HALF_G5;
                                if (dur_counter >= DUR_300MS) begin
                                    playing <= 1'b0;
                                end else dur_counter <= dur_counter + 1'b1;
                            end
                            default: playing <= 1'b0;
                        endcase
                    end

                    // Descending 2-note tone for busting / losing
                    SND_LOSE: begin
                        case (note_step)
                            2'd0: begin
                                current_half_period <= HALF_E4;
                                if (dur_counter >= DUR_250MS) begin
                                    dur_counter <= 27'd0;
                                    note_step   <= 2'd1;
                                end else dur_counter <= dur_counter + 1'b1;
                            end
                            2'd1: begin
                                current_half_period <= HALF_C4;
                                if (dur_counter >= DUR_300MS) begin
                                    playing <= 1'b0;
                                end else dur_counter <= dur_counter + 1'b1;
                            end
                            default: playing <= 1'b0;
                        endcase
                    end

                    default: playing <= 1'b0;
                endcase
            end

            // 3. Square-wave / 50% duty cycle PWM tone generator
            if (playing && (current_half_period > 0)) begin
                if (tone_counter >= current_half_period - 1) begin
                    tone_counter <= 19'd0;
                    audio_out    <= ~audio_out;
                end else begin
                    tone_counter <= tone_counter + 1'b1;
                end
            end else begin
                tone_counter <= 19'd0;
                audio_out    <= 1'b0;
            end
        end
    end

endmodule
