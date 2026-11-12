`timescale 1ns / 1ps

module tb_card_shuffler;

    // Testbench signals
    reg          clk;
    reg          rst;
    reg          start;
    wire         done;
    wire [207:0] deck_flat;
    reg  [3:0]   current_card;
    integer      idx;

    // Instantiate the synthesizable card_shuffler module
    card_shuffler uut (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .done      (done),
        .deck_flat (deck_flat)
    );

    // 1. Generate a 100 MHz clock (10 ns period)
    always #5 clk = ~clk;

    // 2. Stimulus and Print Loop
    initial begin
        // Initialize signals
        clk   = 0;
        rst   = 1;
        start = 0;

        // Hold reset for 20 ns
        #20;
        rst = 0;

        // Wait a few cycles so the free-running LFSR shifts to a new value
        #30;

        // Trigger the shuffle for 1 clock cycle
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait until the module finishes shuffling (51 clock cycles)
        wait (done == 1'b1);
        @(posedge clk);

        // 3. Separate loop to unpack and print the entire 52-card deck
        $display("=================================");
        $display("       SHUFFLED 52-CARD DECK     ");
        $display("=================================");

        // Inside your initial block after wait(done == 1'b1):
        for (idx = 0; idx < 52; idx = idx + 1) begin
            current_card = deck_flat[idx*4 +: 4];
            $display("Position %2d : Card Value %2d", idx, current_card);
        end

        
        $display("=================================");

        // End simulation
        #20;
        $finish;
    end

endmodule


// wire [311:0] shuffled_deck;
// wire shuffle_done;

// card_shuffler u_shuffler (
//     .clk       (clk),
//     .rst       (rst),
//     .start     (start_btn),
//     .done      (shuffle_done),
//     .deck_flat (shuffled_deck)
// );

// // Example: Extract the top 3 cards once done
// wire [5:0] first_card  = shuffled_deck[0*6 +: 6]; // Bits [5:0]
// wire [5:0] second_card = shuffled_deck[1*6 +: 6]; // Bits [11:6]
// wire [5:0] third_card  = shuffled_deck[2*6 +: 6]; // Bits [17:12]
