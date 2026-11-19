module blackjack_top (
    input  wire       clk,
    input  wire       btnC,      // center button: synchronous reset
    input  wire [3:0] sw,        // rightmost 4 switches: active player's aces (0=1, 1=11)

    // internal LEDs
    output wire [5:0] LEDs,      // LEDs[3:0]: active player's aces, LEDs[4]: P1 turn, LEDs[5]: P2 turn

    // internal 4-digit 7-seg display
    output wire [6:0] seg,
    output wire [3:0] an,

    // PMOD 1: 4x4 keypad
    output wire [3:0] kp_row,
    input  wire [3:0] kp_col,

    // PMOD 2: 2-digit 7-seg display
    output wire [6:0] pmod_seg,
    output wire       pmod_cat,

    // PMOD 3 / JXADC top row: speaker
    output wire       audio_out
);

    wire        rst;
    reg         rst_prev;
    wire        start_shuffle;
    wire        shuffle_done;
    wire [207:0] deck_flat;

    wire        clk_1khz;
    wire        hit_pulse;
    wire        stand_pulse;

    wire [5:0]  deck_idx;
    wire [5:0]  next_deck_idx = (deck_idx == 6'd51) ? 6'd0 : (deck_idx + 6'd1);

    wire [3:0]  raw_card_a = deck_flat[deck_idx*4 +: 4];
    wire [3:0]  raw_card_b = deck_flat[next_deck_idx*4 +: 4];

    wire        card_a_is_ace = (raw_card_a == 4'd1);
    wire        card_b_is_ace = (raw_card_b == 4'd1);

    wire [3:0]  card_a_points = card_a_is_ace ? 4'd0 : ((raw_card_a >= 4'd10) ? 4'd10 : raw_card_a);
    wire [3:0]  card_b_points = card_b_is_ace ? 4'd0 : ((raw_card_b >= 4'd10) ? 4'd10 : raw_card_b);

    wire [3:0]  active_ace_leds;
    wire [4:0]  p1_display_total;
    wire [4:0]  p2_display_total;
    wire        p1_turn;
    wire        p2_turn;
    wire        first_draw_view;
    wire        show_p1_half;
    wire        show_p2_half;
    wire        blank_all;
    wire        game_over;
    wire        flash_p1;
    wire        flash_p2;

    wire [3:0]  pmod_card_val;
    wire        pmod_blank;
    wire [1:0]  sound_code;
    wire        sound_trig;

    debouncer db_rst (
        .clk(clk),
        .noisy_in(btnC),
        .clean_out(rst)
    );

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

    clock_divider clk_div (
        .clk(clk),
        .rst(rst),
        .clk_1khz(clk_1khz)
    );

    keypad_scanner kp_inst (
        .clk(clk),
        .clk_scan(clk_1khz),
        .rst(rst),
        .row(kp_row),
        .col(kp_col),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse)
    );

    blackjack_fsm #(
        .CLK_FREQ(100_000_000)
    ) game_fsm (
        .clk(clk),
        .rst(rst),
        .shuffle_done(shuffle_done),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse),
        .raw_card_a(raw_card_a),
        .raw_card_b(raw_card_b),
        .card_a_points(card_a_points),
        .card_b_points(card_b_points),
        .card_a_is_ace(card_a_is_ace),
        .card_b_is_ace(card_b_is_ace),
        .sw(sw[3:0]),
        .deck_idx(deck_idx),
        .active_ace_leds(active_ace_leds),
        .p1_display_total(p1_display_total),
        .p2_display_total(p2_display_total),
        .p1_turn(p1_turn),
        .p2_turn(p2_turn),
        .first_draw_view(first_draw_view),
        .show_p1_half(show_p1_half),
        .show_p2_half(show_p2_half),
        .blank_all(blank_all),
        .game_over(game_over),
        .flash_p1(flash_p1),
        .flash_p2(flash_p2),
        .pmod_card_val(pmod_card_val),
        .pmod_blank(pmod_blank),
        .sound_code(sound_code),
        .sound_trig(sound_trig)
    );

    assign LEDs[3:0] = active_ace_leds;
    assign LEDs[4]   = p1_turn;
    assign LEDs[5]   = p2_turn;

    seven_seg_internal disp_internal (
        .clk(clk),
        .clk_1khz(clk_1khz),
        .rst(rst),
        .left_val(p2_display_total),
        .right_val(p1_display_total),
        .first_draw_view(first_draw_view),
        .show_left(show_p2_half),
        .show_right(show_p1_half),
        .blank_all(blank_all),
        .flash_left(flash_p2),
        .flash_right(flash_p1),
        .seg(seg),
        .an(an)
    );

    seven_seg_pmod disp_pmod (
        .clk_1khz(clk_1khz),
        .rst(rst),
        .card_val(pmod_card_val),
        .blank(pmod_blank),
        .pmod_seg(pmod_seg),
        .pmod_cat(pmod_cat)
    );

    pwm_audio #(
        .CLK_FREQ(100_000_000)
    ) speaker_inst (
        .clk(clk),
        .rst(rst),
        .sound_code(sound_code),
        .sound_trig(sound_trig),
        .audio_out(audio_out)
    );

endmodule
