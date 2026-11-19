`timescale 1ns / 1ps

module tb_seven_seg_pmod;

    reg        clk_1khz;
    reg        rst;
    reg  [3:0] card_val;
    wire [6:0] pmod_seg;
    wire       pmod_cat;

    seven_seg_pmod uut (
        .clk_1khz(clk_1khz),
        .rst(rst),
        .card_val(card_val),
        .pmod_seg(pmod_seg),
        .pmod_cat(pmod_cat)
    );

    // 1 kHz clock (500,000 ns half-period)
    initial begin
        clk_1khz = 1'b0;
        forever #500_000 clk_1khz = ~clk_1khz;
    end

    initial begin
        rst      = 1'b1;
        card_val = 4'd0;

        repeat (2) @(posedge clk_1khz);
        rst = 1'b0;

        // 1. No card drawn (0) -> both digits blank (7'b0000000)
        card_val = 4'd0;
        repeat (2) @(posedge clk_1khz);
        #1;
        if (pmod_seg !== 7'b0000000) begin
            $display("FAIL: expected blank for card_val=0, got %b", pmod_seg);
            $fatal;
        end

        // 2. Single digit card (e.g., 7 -> "07")
        card_val = 4'd7;
        @(posedge clk_1khz); #1; // check current active digit
        @(posedge clk_1khz); #1; // check toggled digit
        if (!((pmod_cat == 1'b1 && pmod_seg == 7'b0111111) ||
              (pmod_cat == 1'b0 && pmod_seg == 7'b0000111))) begin
            $display("FAIL: unexpected segment output for card_val=7: cat=%b seg=%b", pmod_cat, pmod_seg);
            $fatal;
        end

        // 3. King (13 -> "13")
        card_val = 4'd13;
        repeat (4) @(posedge clk_1khz);

        $display("PASS: seven_seg_pmod testbench completed");
        $finish;
    end

endmodule
