module blackjack_fsm #(
    parameter integer CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       shuffle_done,
    input  wire       hit_pulse,
    input  wire       stand_pulse,
    input  wire [3:0] raw_card_a,
    input  wire [3:0] raw_card_b,
    input  wire [3:0] card_a_points,
    input  wire [3:0] card_b_points,
    input  wire       card_a_is_ace,
    input  wire       card_b_is_ace,
    input  wire [3:0] sw,
    output reg  [5:0] deck_idx,
    output reg  [3:0] active_ace_leds,
    output wire [4:0] p1_display_total,
    output wire [4:0] p2_display_total,
    output wire       p1_turn,
    output wire       p2_turn,
    output wire       first_draw_view,
    output wire       show_p1_half,
    output wire       show_p2_half,
    output wire       blank_all,
    output wire       game_over,
    output wire       flash_p1,
    output wire       flash_p2,
    output reg  [3:0] pmod_card_val,
    output reg        pmod_blank,
    output reg  [1:0] sound_code,
    output reg        sound_trig
);

    localparam [2:0] S_SHUFFLE       = 3'd0,
                     S_P1_TURN       = 3'd1,
                     S_P1_STAY_PAUSE = 3'd2,
                     S_P2_TURN       = 3'd3,
                     S_GAME_OVER     = 3'd4;

    localparam integer TWO_SEC_TICKS = CLK_FREQ * 2;

    reg [2:0]  state, next_state;
    reg [27:0] pause_cnt;

    // Independent state for Player 1 and Player 2
    reg [4:0]  p1_base_total, p2_base_total;
    reg [3:0]  p1_ace_mask, p2_ace_mask;
    reg [3:0]  p1_first_c1, p1_first_c2;
    reg [3:0]  p2_first_c1, p2_first_c2;
    reg        p1_first_done, p2_first_done;
    reg        p1_viewing_pair, p2_viewing_pair;
    reg        p1_locked, p2_locked;
    reg [4:0]  p1_locked_total, p2_locked_total;

    // Ace value helper: sw[k] == 0 -> +1, sw[k] == 1 -> +11
    function [5:0] calc_ace_points;
        input [3:0] mask;
        input [3:0] switches;
        reg [5:0] sum;
        integer idx;
        begin
            sum = 6'd0;
            for (idx = 0; idx < 4; idx = idx + 1) begin
                if (mask[idx]) begin
                    sum = sum + (switches[idx] ? 6'd11 : 6'd1);
                end
            end
            calc_ace_points = sum;
        end
    endfunction

    function [3:0] add_ace_bit;
        input [3:0] mask;
        begin
            if (!mask[0])      add_ace_bit = {mask[3:1], 1'b1};
            else if (!mask[1]) add_ace_bit = {mask[3:2], 1'b1, mask[0]};
            else if (!mask[2]) add_ace_bit = {mask[3], 1'b1, mask[1:0]};
            else if (!mask[3]) add_ace_bit = {1'b1, mask[2:0]};
            else               add_ace_bit = mask;
        end
    endfunction

    function [5:0] advance_deck;
        input [5:0] cur_idx;
        input [5:0] step;
        begin
            if ((cur_idx + step) >= 6'd52)
                advance_deck = (cur_idx + step) - 6'd52;
            else
                advance_deck = cur_idx + step;
        end
    endfunction

    wire [5:0] p1_ace_pts = calc_ace_points(p1_ace_mask, sw);
    wire [5:0] p2_ace_pts = calc_ace_points(p2_ace_mask, sw);

    wire [4:0] p1_live_total = p1_base_total + p1_ace_pts[4:0];
    wire [4:0] p2_live_total = p2_base_total + p2_ace_pts[4:0];

    wire [4:0] p1_cur_total = p1_locked ? p1_locked_total : p1_live_total;
    wire [4:0] p2_cur_total = p2_locked ? p2_locked_total : p2_live_total;

    // During first-draw pair display, left 2 digits = card 1, right 2 digits = card 2
    assign p1_display_total = p1_viewing_pair ? {1'b0, p1_first_c2} : p1_cur_total;
    assign p2_display_total = p1_viewing_pair ? {1'b0, p1_first_c1} :
                              (p2_viewing_pair ? {1'b0, p2_first_c1} : p2_cur_total);

    assign p1_turn         = (state == S_P1_TURN);
    assign p2_turn         = (state == S_P2_TURN);
    assign first_draw_view = ((state == S_P1_TURN) && p1_viewing_pair) ||
                             ((state == S_P2_TURN) && p2_viewing_pair);
    assign blank_all       = (state == S_SHUFFLE) || (state == S_P1_STAY_PAUSE);
    assign game_over       = (state == S_GAME_OVER);

    // Before game over, show only active player's side (except during first-draw pair view)
    assign show_p1_half = (state == S_GAME_OVER) ||
                          ((state == S_P1_TURN) && !p1_viewing_pair);
    assign show_p2_half = (state == S_GAME_OVER) ||
                          ((state == S_P1_TURN) && p1_viewing_pair) ||
                          ((state == S_P2_TURN));

    // Winner / tie detection at game over (<= 21 beats > 21; higher <= 21 wins; equal = tie)
    wire p1_bust = (p1_locked_total > 5'd21);
    wire p2_bust = (p2_locked_total > 5'd21);
    wire p1_wins = game_over && !p1_bust && (p2_bust || (p1_locked_total > p2_locked_total));
    wire p2_wins = game_over && !p2_bust && (p1_bust || (p2_locked_total > p1_locked_total));
    wire is_tie  = game_over && !p1_wins && !p2_wins;

    assign flash_p1 = p1_wins || is_tie;
    assign flash_p2 = p2_wins || is_tie;

    // Active LEDs show current player's aces
    always @(*) begin
        if (state == S_P2_TURN)
            active_ace_leds = p2_ace_mask;
        else
            active_ace_leds = p1_ace_mask;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_SHUFFLE: begin
                if (shuffle_done)
                    next_state = S_P1_TURN;
            end

            S_P1_TURN: begin
                if (stand_pulse)
                    next_state = S_P1_STAY_PAUSE;
            end

            S_P1_STAY_PAUSE: begin
                if (pause_cnt >= TWO_SEC_TICKS - 1)
                    next_state = S_P2_TURN;
            end

            S_P2_TURN: begin
                if (stand_pulse)
                    next_state = S_GAME_OVER;
            end

            S_GAME_OVER: begin
                next_state = S_GAME_OVER;
            end

            default: next_state = S_SHUFFLE;
        endcase
    end

    // Sequential state, card draw, ace, sound, and pause logic
    always @(posedge clk) begin
        if (rst) begin
            state           <= S_SHUFFLE;
            next_state      <= S_SHUFFLE;
            pause_cnt       <= 28'd0;
            deck_idx        <= 6'd0;
            p1_base_total   <= 5'd0;
            p2_base_total   <= 5'd0;
            p1_ace_mask     <= 4'b0000;
            p2_ace_mask     <= 4'b0000;
            p1_first_c1     <= 4'd0;
            p1_first_c2     <= 4'd0;
            p2_first_c1     <= 4'd0;
            p2_first_c2     <= 4'd0;
            p1_first_done   <= 1'b0;
            p2_first_done   <= 1'b0;
            p1_viewing_pair <= 1'b0;
            p2_viewing_pair <= 1'b0;
            p1_locked       <= 1'b0;
            p2_locked       <= 1'b0;
            p1_locked_total <= 5'd0;
            p2_locked_total <= 5'd0;
            pmod_card_val   <= 4'd0;
            pmod_blank      <= 1'b1;
            sound_code      <= 2'b00;
            sound_trig      <= 1'b0;
        end else begin
            state      <= next_state;
            sound_trig <= 1'b0;

            case (state)
                S_SHUFFLE: begin
                    pause_cnt  <= 28'd0;
                    pmod_blank <= 1'b1;
                end

                S_P1_TURN: begin
                    if (hit_pulse) begin
                        if (!p1_first_done) begin
                            // First draw: draw two cards and display both across full board
                            p1_first_c1     <= raw_card_a;
                            p1_first_c2     <= raw_card_b;
                            p1_first_done   <= 1'b1;
                            p1_viewing_pair <= 1'b1;
                            pmod_card_val   <= raw_card_b;
                            pmod_blank      <= 1'b0;
                            deck_idx        <= advance_deck(deck_idx, 6'd2);

                            // Accumulate both cards' points/aces into P1 hand
                            p1_base_total <= p1_base_total +
                                             (card_a_is_ace ? 5'd0 : {1'b0, card_a_points}) +
                                             (card_b_is_ace ? 5'd0 : {1'b0, card_b_points});
                            case ({card_a_is_ace, card_b_is_ace})
                                2'b01: p1_ace_mask <= add_ace_bit(p1_ace_mask);
                                2'b10: p1_ace_mask <= add_ace_bit(p1_ace_mask);
                                2'b11: p1_ace_mask <= add_ace_bit(add_ace_bit(p1_ace_mask));
                                default: ;
                            endcase
                        end else begin
                            // Subsequent draws: sum first pair + drawn card on P1's half
                            p1_viewing_pair <= 1'b0;
                            pmod_card_val   <= raw_card_a;
                            pmod_blank      <= 1'b0;
                            deck_idx        <= advance_deck(deck_idx, 6'd1);

                            if (card_a_is_ace) begin
                                p1_ace_mask <= add_ace_bit(p1_ace_mask);
                            end else begin
                                p1_base_total <= p1_base_total + {1'b0, card_a_points};
                            end
                        end
                    end else if (stand_pulse) begin
                        // Stay: lock P1 total, blank Pmod display, 1 beep, 2-second blank pause
                        p1_viewing_pair <= 1'b0;
                        p1_locked       <= 1'b1;
                        p1_locked_total <= p1_live_total;
                        pmod_blank      <= 1'b1;
                        pause_cnt       <= 28'd0;
                        sound_code      <= 2'b01; // 1 beep for P1 turn end
                        sound_trig      <= 1'b1;
                    end
                end

                S_P1_STAY_PAUSE: begin
                    pmod_blank <= 1'b1;
                    if (pause_cnt < TWO_SEC_TICKS - 1) begin
                        pause_cnt <= pause_cnt + 28'd1;
                    end else begin
                        pause_cnt <= 28'd0;
                    end
                end

                S_P2_TURN: begin
                    if (hit_pulse) begin
                        if (!p2_first_done) begin
                            p2_first_c1     <= raw_card_a;
                            p2_first_c2     <= raw_card_b;
                            p2_first_done   <= 1'b1;
                            p2_viewing_pair <= 1'b1;
                            pmod_card_val   <= raw_card_b;
                            pmod_blank      <= 1'b0;
                            deck_idx        <= advance_deck(deck_idx, 6'd2);

                            p2_base_total <= p2_base_total +
                                             (card_a_is_ace ? 5'd0 : {1'b0, card_a_points}) +
                                             (card_b_is_ace ? 5'd0 : {1'b0, card_b_points});
                            case ({card_a_is_ace, card_b_is_ace})
                                2'b01: p2_ace_mask <= add_ace_bit(p2_ace_mask);
                                2'b10: p2_ace_mask <= add_ace_bit(p2_ace_mask);
                                2'b11: p2_ace_mask <= add_ace_bit(add_ace_bit(p2_ace_mask));
                                default: ;
                            endcase
                        end else begin
                            p2_viewing_pair <= 1'b0;
                            pmod_card_val   <= raw_card_a;
                            pmod_blank      <= 1'b0;
                            deck_idx        <= advance_deck(deck_idx, 6'd1);

                            if (card_a_is_ace) begin
                                p2_ace_mask <= add_ace_bit(p2_ace_mask);
                            end else begin
                                p2_base_total <= p2_base_total + {1'b0, card_a_points};
                            end
                        end
                    end else if (stand_pulse) begin
                        // Stay: lock P2 total, blank Pmod display, distinct game-over sound
                        p2_viewing_pair <= 1'b0;
                        p2_locked       <= 1'b1;
                        p2_locked_total <= p2_live_total;
                        pmod_blank      <= 1'b1;
                        sound_code      <= 2'b10; // Distinct sound for game ended
                        sound_trig      <= 1'b1;
                    end
                end

                S_GAME_OVER: begin
                    pmod_blank <= 1'b1;
                end
            endcase
        end
    end

endmodule
