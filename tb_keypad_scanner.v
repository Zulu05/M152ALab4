`timescale 1ns / 1ps

module tb_keypad_scanner;

    reg        clk;
    reg        clk_scan;
    reg        rst;
    wire [3:0] row;
    wire [3:0] col;
    wire       hit_pulse;
    wire       stand_pulse;

    // Simulated key press flags in testbench
    reg key1_pressed; // Row 0, Col 0 -> Hit
    reg key2_pressed; // Row 0, Col 1 -> Stand

    // Model pull-ups on columns and active-low switch closure on Row 0 (row[0] == 0)
    wire col0_drive = (key1_pressed && (row[0] == 1'b0)) ? 1'b0 : 1'b1;
    wire col1_drive = (key2_pressed && (row[0] == 1'b0)) ? 1'b0 : 1'b1;
    assign col = {1'b1, 1'b1, col1_drive, col0_drive};

    // Use a small DEBOUNCE_TICKS (3 scan cycles) for fast simulation
    keypad_scanner #(.DEBOUNCE_TICKS(3)) uut (
        .clk(clk),
        .clk_scan(clk_scan),
        .rst(rst),
        .row(row),
        .col(col),
        .hit_pulse(hit_pulse),
        .stand_pulse(stand_pulse)
    );

    // 100 MHz system clock (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 1 kHz scan clock (1 ms = 1,000,000 ns period -> 500,000 ns half-period)
    initial begin
        clk_scan = 1'b0;
        forever #500_000 clk_scan = ~clk_scan;
    end

    integer hit_pulse_count;
    integer stand_pulse_count;

    always @(posedge clk) begin
        if (rst) begin
            hit_pulse_count   <= 0;
            stand_pulse_count <= 0;
        end else begin
            if (hit_pulse)   hit_pulse_count   <= hit_pulse_count + 1;
            if (stand_pulse) stand_pulse_count <= stand_pulse_count + 1;
        end
    end

    initial begin
        rst          = 1'b1;
        key1_pressed = 1'b0;
        key2_pressed = 1'b0;

        // Hold reset for 3 scan cycles
        repeat (3) @(posedge clk_scan);
        rst = 1'b0;
        repeat (4) @(posedge clk_scan);

        // Test 1: Press and hold Key '1' (Hit) for 20 ms
        key1_pressed = 1'b1;
        repeat (20) @(posedge clk_scan);
        if (hit_pulse_count != 1) begin
            $display("FAIL: Expected 1 hit_pulse for Key 1 press, got %0d", hit_pulse_count);
            $fatal;
        end

        // Release Key '1'
        key1_pressed = 1'b0;
        repeat (10) @(posedge clk_scan);

        // Test 2: Press and hold Key '2' (Stand) for 20 ms
        key2_pressed = 1'b1;
        repeat (20) @(posedge clk_scan);
        if (stand_pulse_count != 1) begin
            $display("FAIL: Expected 1 stand_pulse for Key 2 press, got %0d", stand_pulse_count);
            $fatal;
        end

        // Release Key '2'
        key2_pressed = 1'b0;
        repeat (10) @(posedge clk_scan);

        $display("PASS: hit_pulse=%0d, stand_pulse=%0d", hit_pulse_count, stand_pulse_count);
        $finish;
    end

endmodule
