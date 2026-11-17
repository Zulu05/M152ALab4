module blackjack_top (
    input wire clk,        
    input wire btnC,  // center button: synchronous reset
    input wire [0:0] sw,  // sw[0]: 0 = P1 mode, 1 = P2 mode
    
    // internal 4-digit 7-seg display
    output wire [6:0] seg,
    output wire [3:0] an,
    
    // PMOD 1: 4x4 keypad
    output wire [3:0] kp_row,
    input wire [3:0] kp_col,
    
    // PMOD 2: 2-digit 7-seg display
    output wire [6:0] pmod_seg,
    output wire pmod_cat,  // digit select pin
    
    // PMOD 3: speaker
    output wire audio_out
);

    wire rst;
    wire clk_1khz;
    wire hit_pulse;  // single-cycle pulse when 1 is pressed
    wire stand_pulse;  // single-cycle pulse when 2 is pressed
    wire [3:0] random_card;  // card value (1-11)
    wire [4:0] p1_total;  // player 1 score (0-31)
    wire [4:0] p2_total;  // player 2 score (0-31)
    wire [3:0] last_card;  // most recently drawn card
    wire [1:0] sound_code;  // 00: silent, 01: switch turns, 10: game ends

    // debounce reset button
    debouncer db_rst (
        .clk(clk),
        .noisy_in(btnC),
        .clean_out(rst)
    );

    // clock divider for display multiplexing and keypad scanning
    clock_divider clk_div (
        .clk(clk),
        .rst(rst),
        .clk_1khz(clk_1khz)
    );

    // PMOD 1: keypad scanner (outputs 1-cycle pulses on key press)
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
        .player_mode(sw[0]),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse),
        .random_card(random_card),
        .p1_total(p1_total),
        .p2_total(p2_total),
        .last_card(last_card),
        .sound_code(sound_code)
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
