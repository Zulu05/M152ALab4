module card_shuffler (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,         // Pulse high for 1 cycle to begin shuffling
    output reg          done,          // High when the shuffled deck is ready
    output reg  [207:0] deck_flat      // 52 cards * 4 bits per card = 208 bits
);

    // Internal array to hold 52 cards (values 1 to 13, four of each)
    reg [3:0] deck [0:51];
    
    // State machine definitions
    localparam IDLE    = 2'd0,
               SHUFFLE = 2'd1,
               DONE    = 2'd2;
               
    reg [1:0]  state;
    reg [5:0]  i;           // Loop index from 51 down to 1 (still needs 6 bits)
    reg [15:0] lfsr;        // 16-bit PRNG
    
    // Combinational calculation for random swap index j (0 <= j <= i)
    wire [22:0] mult = lfsr * (i + 7'd1);
    wire [5:0]  j = mult[21:16]; 

    integer k;

    // 1. Free-running 16-bit LFSR for pseudo-randomness
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr <= 16'hACE1; // Non-zero seed
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end

    // 2. Fisher-Yates Shuffle State Machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;
            i     <= 6'd51;
            for (k = 0; k < 52; k = k + 1) begin
                deck[k] <= (k % 13) + 4'd1;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load 4 sets of 1..13 before shuffling
                        for (k = 0; k < 52; k = k + 1) begin
                            deck[k] <= (k % 13) + 4'd1;
                        end
                        i     <= 6'd51;
                        state <= SHUFFLE;
                    end
                end

                SHUFFLE: begin
                    // Swap deck[i] and deck[j]
                    deck[i] <= deck[j];
                    deck[j] <= deck[i];

                    if (i == 6'd1) begin
                        state <= DONE;
                    end else begin
                        i <= i - 6'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // 3. Pack the 2D array into the 208-bit flattened output bus
    always @(*) begin
        for (k = 0; k < 52; k = k + 1) begin
            deck_flat[k*4 +: 4] = deck[k];
        end
    end

endmodule


