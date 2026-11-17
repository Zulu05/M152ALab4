module blackjack_top (
    input wire clk,
    input wire btnC, // center button: synchronous reset
    input wire [4:0] sw, // sw[0]: turn mode, sw[2:1]: P1 aces, sw[4:3]: P2 aces
    
    // internal LEDs for drawn aces
    output wire [3:0] LEDs, // LEDs[1:0]: P1 aces, LEDs[3:2]: P2 aces
    
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

    wire [5:0] deck_idx; // tracked inside game_fsm (0 to 51)
    wire [3:0] raw_card; // 1 to 13 from shuffled deck
    wire [3:0] card_points; // 0 for ace (handled by ace_counter), 2-10 for others
    wire is_ace;

    wire [4:0] p1_base_total;
    wire [4:0] p2_base_total;
    wire [5:0] p1_ace_total;
    wire [5:0] p2_ace_total;
    wire [4:0] p1_total = p1_base_total + p1_ace_total[4:0];
    wire [4:0] p2_total = p2_base_total + p2_ace_total[4:0];

    wire [3:0] last_card;
    wire [1:0] sound_code;

    // debounce reset button
    debouncer db_rst (
        .clk(clk),
        .noisy_in(btnC),
        .clean_out(rst)
    );

    // pulse start_shuffle for 1 cycle immediately after reset is released
    always @(posedge clk) begin
        rst_prev <= rst;
    end
    assign start_shuffle = ~rst & rst_prev;

    // shuffler
    card_shuffler shuffler_inst (
        .clk(clk),
        .rst(rst),
        .start(start_shuffle),
        .done(shuffle_done),
        .deck_flat(deck_flat)
    );

    // slice current card from deck and convert to Blackjack points
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

    // core blackjack game FSM (updated to track deck_idx, ace LEDs, and base scores)
    blackjack_fsm game_fsm (
        .clk(clk),
        .rst(rst),
        .shuffle_done(shuffle_done),
        .player_mode(sw[0]),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse),
        .raw_card(raw_card),
        .card_points(card_points),
        .is_ace(is_ace),
        .p1_total(p1_total),
        .p2_total(p2_total),
        .deck_idx(deck_idx),
        .ace_leds(LEDs),
        .p1_base_total(p1_base_total),
        .p2_base_total(p2_base_total),
        .last_card(last_card),
        .sound_code(sound_code)
    );

    // player 1 ace counter (uses LEDs[1:0] and sw[2:1])
    ace_counter p1_aces (
        .LEDs({2'b00, LEDs[1:0]}),
        .sw({2'b00, sw[2:1]}),
        .total(p1_ace_total)
    );

    // player 2 ace counter (uses LEDs[3:2] and sw[4:3])
    ace_counter p2_aces (
        .LEDs({2'b00, LEDs[3:2]}),
        .sw({2'b00, sw[4:3]}),
        .total(p2_ace_total)
    );

    // internal 4-digit 7-segment controller (left = P2, right = P1)
    seven_seg_internal disp_internal (
        .clk_1khz(clk_1khz),
        .rst(rst),
        .left_val(p2_total),
        .right_val(p1_total),
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
