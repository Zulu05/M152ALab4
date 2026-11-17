module blackjack_fsm (
    input wire clk,
    input wire rst,
    input wire shuffle_done,
    input wire hit_pulse,
    input wire stand_pulse,
    input wire [3:0] raw_card,
    input wire [3:0] card_points,
    input wire is_ace,
    input wire [4:0] p1_live_total,
    input wire [4:0] p2_live_total,
    output reg [5:0] deck_idx,
    output reg [3:0] p1_ace_leds,
    output reg [3:0] p2_ace_leds,
    output reg [4:0] p1_base_total,
    output reg [4:0] p2_base_total,
    output wire [4:0] p1_final_total,
    output wire [4:0] p2_final_total,
    output wire p1_turn,
    output wire p2_turn,
    output wire game_over,
    output reg [3:0] last_card,
    output reg [1:0] sound_code
);

    localparam S_SHUFFLE = 3'd0;
    localparam S_P1_TURN = 3'd1;
    localparam S_P2_TURN = 3'd2;
    localparam S_GAME_OVER = 3'd3;

    reg [2:0] state, next_state;
    reg p1_stood, p2_stood;
    reg [4:0] p1_locked_total, p2_locked_total;

    // output locked score once a player stands or busts so shared switches can move freely
    assign p1_final_total = p1_stood ? p1_locked_total : p1_live_total;
    assign p2_final_total = p2_stood ? p2_locked_total : p2_live_total;
    assign p1_turn = (state == S_P1_TURN);
    assign p2_turn = (state == S_P2_TURN);
    assign game_over = (state == S_GAME_OVER);

    // minimum possible score if every drawn ace is counted as 1
    wire [4:0] p1_min_total = p1_base_total + {4'd0, p1_ace_leds[0]} + {4'd0, p1_ace_leds[1]} + {4'd0, p1_ace_leds[2]} + {4'd0, p1_ace_leds[3]};
    wire [4:0] p2_min_total = p2_base_total + {4'd0, p2_ace_leds[0]} + {4'd0, p2_ace_leds[1]} + {4'd0, p2_ace_leds[2]} + {4'd0, p2_ace_leds[3]};

    wire [4:0] card_min_val = is_ace ? 5'd1 : {1'b0, card_points};

    // sequential state, score, and deck updates
    always @(posedge clk) begin
        if (rst) begin
            state <= S_SHUFFLE;
            deck_idx <= 6'd0;
            p1_ace_leds <= 4'b0000;
            p2_ace_leds <= 4'b0000;
            p1_base_total <= 5'd0;
            p2_base_total <= 5'd0;
            p1_locked_total <= 5'd0;
            p2_locked_total <= 5'd0;
            last_card <= 4'd0;
            p1_stood <= 1'b0;
            p2_stood <= 1'b0;
            sound_code <= 2'b00;
        end else begin
            state <= next_state;

            case (state)
                S_SHUFFLE: begin
                    sound_code <= 2'b00;
                end

                S_P1_TURN: begin
                    if (p1_min_total > 5'd21) begin
                        p1_stood <= 1'b1;
                        p1_locked_total <= p1_live_total;
                    end else if (hit_pulse) begin
                        last_card <= raw_card;
                        deck_idx <= (deck_idx == 6'd51) ? 6'd0 : deck_idx + 6'd1;

                        if (is_ace) begin
                            if (!p1_ace_leds[0])
                                p1_ace_leds[0] <= 1'b1;
                            else if (!p1_ace_leds[1])
                                p1_ace_leds[1] <= 1'b1;
                            else if (!p1_ace_leds[2])
                                p1_ace_leds[2] <= 1'b1;
                            else if (!p1_ace_leds[3])
                                p1_ace_leds[3] <= 1'b1;
                        end else begin
                            p1_base_total <= p1_base_total + {1'b0, card_points};
                        end

                        sound_code <= (p1_min_total + card_min_val > 5'd21) ? 2'b11 : 2'b01;
                    end else if (stand_pulse) begin
                        p1_stood <= 1'b1;
                        p1_locked_total <= p1_live_total;
                        sound_code <= 2'b00;
                    end
                end

                S_P2_TURN: begin
                    if (p2_min_total > 5'd21) begin
                        p2_stood <= 1'b1;
                        p2_locked_total <= p2_live_total;
                    end else if (hit_pulse) begin
                        last_card <= raw_card;
                        deck_idx <= (deck_idx == 6'd51) ? 6'd0 : deck_idx + 6'd1;

                        if (is_ace) begin
                            if (!p2_ace_leds[0])
                                p2_ace_leds[0] <= 1'b1;
                            else if (!p2_ace_leds[1])
                                p2_ace_leds[1] <= 1'b1;
                            else if (!p2_ace_leds[2])
                                p2_ace_leds[2] <= 1'b1;
                            else if (!p2_ace_leds[3])
                                p2_ace_leds[3] <= 1'b1;
                        end else begin
                            p2_base_total <= p2_base_total + {1'b0, card_points};
                        end

                        sound_code <= (p2_min_total + card_min_val > 5'd21) ? 2'b11 : 2'b01;
                    end else if (stand_pulse) begin
                        p2_stood <= 1'b1;
                        p2_locked_total <= p2_live_total;
                        sound_code <= 2'b00;
                    end
                end

                S_GAME_OVER: begin
                    if (p1_final_total > 5'd21 || p2_final_total > 5'd21)
                        sound_code <= 2'b11;
                    else
                        sound_code <= 2'b10;
                end
            endcase
        end
    end

    // next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_SHUFFLE: begin
                if (shuffle_done)
                    next_state = S_P1_TURN;
            end

            S_P1_TURN: begin
                if (p1_min_total > 5'd21)
                    next_state = S_GAME_OVER;
                else if (stand_pulse)
                    next_state = (p1_live_total > 5'd21) ? S_GAME_OVER : S_P2_TURN;
            end

            S_P2_TURN: begin
                if (p2_min_total > 5'd21 || stand_pulse)
                    next_state = S_GAME_OVER;
            end

            S_GAME_OVER: begin
                next_state = S_GAME_OVER;
            end
        endcase
    end

endmodule
