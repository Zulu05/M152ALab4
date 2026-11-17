module blackjack_top (
    input wire clk,
    input wire btnC, // center button: synchronous reset
    input wire [3:0] sw, // rightmost 4 switches: active player's aces
    
    // internal LEDs
    output wire [5:0] LEDs, // LEDs[3:0]: active player's aces, LEDs[4]: P1 turn, LEDs[5]: P2 turn
    
    // internal 4-digit 7-seg display
    output wire [6:0] seg,
    output wire [3:0] an,
    
    // PMOD 1: 4x4 keypad
    output wire [3:0] kp_row,
    input wire [3:0] kp_col,
    
    // PMOD 2: 2-digit 7-seg display
    output wire [6:0] pmod_seg,
    output wire pmod_cat,
    
    // PMOD 3: speaker
    output wire audio_out
);

    wire rst;
    reg rst_prev;
    wire start_shuffle;
    wire shuffle_done;
    wire [207:0] deck_flat;

    wire clk_1khz;
    wire hit_pulse;
    wire stand_pulse;

    wire [5:0] deck_idx;
    wire [3:0] raw_card;
    wire [3:0] card_points;
    wire is_ace;

    wire [3:0] p1_ace_leds;
    wire [3:0] p2_ace_leds;
    wire [3:0] active_ace_leds;
    wire [4:0] p1_base_total;
    wire [4:0] p2_base_total;
    wire [5:0] active_ace_total;

    wire [4:0] p1_live_total = p1_base_total + active_ace_total[4:0];
    wire [4:0] p2_live_total = p2_base_total + active_ace_total[4:0];
    wire [4:0] p1_final_total;
    wire [4:0] p2_final_total;
    wire p1_turn;
    wire p2_turn;
    wire game_over;

    wire [3:0] last_card;
    wire [1:0] sound_code;

    // debounce reset button
    debouncer db_rst (
        .clk(clk),
        .noisy_in(btnC),
        .clean_out(rst)
    );

    // pulse start_shuffle for 1 cycle after reset is released
    always @(posedge clk) begin
        rst_prev <= rst;
    end
    assign start_shuffle = ~rst & rst_prev;

    card_shuffler shuffler_inst (
        .clk(clk),
        .rst(rst),
        .start(start_shuffle),
        .done(shuffle_done),
        .deck_flat(deck_flat)
    );

    // slice current card and convert face cards (11-13) to 10 points
    assign raw_card = deck_flat[deck_idx*4 +: 4];
    assign is_ace = (raw_card == 4'd1);
    assign card_points = is_ace ? 4'd0 : ((raw_card >= 4'd10) ? 4'd10 : raw_card);

    // clock divider
    clock_divider clk_div (
        .clk(clk),
        .rst(rst),
        .clk_1khz(clk_1khz)
    );

    // PMOD 1: keypad scanner
    keypad_scanner kp_inst (
        .clk(clk),
        .clk_scan(clk_1khz),
        .rst(rst),
        .row(kp_row),
        .col(kp_col),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse)
    );

    // core blackjack game FSM
    blackjack_fsm game_fsm (
        .clk(clk),
        .rst(rst),
        .shuffle_done(shuffle_done),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse),
        .raw_card(raw_card),
        .card_points(card_points),
        .is_ace(is_ace),
        .p1_live_total(p1_live_total),
        .p2_live_total(p2_live_total),
        .deck_idx(deck_idx),
        .p1_ace_leds(p1_ace_leds),
        .p2_ace_leds(p2_ace_leds),
        .p1_base_total(p1_base_total),
        .p2_base_total(p2_base_total),
        .p1_final_total(p1_final_total),
        .p2_final_total(p2_final_total),
        .p1_turn(p1_turn),
        .p2_turn(p2_turn),
        .game_over(game_over),
        .last_card(last_card),
        .sound_code(sound_code)
    );

    // route active player's ace LEDs to the single shared ace_counter
    assign active_ace_leds = p2_turn ? p2_ace_leds : p1_ace_leds;

    ace_counter shared_aces (
        .LEDs(active_ace_leds),
        .sw(sw[3:0]),
        .total(active_ace_total)
    );

    // drive rightmost 4 LEDs with active player's aces, plus 2 turn indicator LEDs
    assign LEDs[3:0] = active_ace_leds;
    assign LEDs[4] = p1_turn;
    assign LEDs[5] = p2_turn;

    // internal 4-digit 7-segment controller (left = P2, right = P1)
    seven_seg_internal disp_internal (
        .clk_1khz(clk_1khz),
        .rst(rst),
        .left_val(p2_final_total),
        .right_val(p1_final_total),
        .seg(seg),
        .an(an)
    );

    // PMOD 2: external 2-digit 7-seg controller (last card drawn)
    seven_seg_pmod disp_pmod (
        .clk_1khz(clk_1khz),
        .rst(rst),
        .card_val(last_card),
        .pmod_seg(pmod_seg),
        .pmod_cat(pmod_cat)
    );

    // PMOD 3: pwm speaker driver
    pwm_audio speaker_inst (
        .clk(clk),
        .rst(rst),
        .sound_code(sound_code),
        .audio_out(audio_out)
    );

endmodule
