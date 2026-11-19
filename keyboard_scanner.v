`timescale 1ns / 1ps

module keypad_scanner #(
    parameter integer DEBOUNCE_TICKS = 20 // 20 ms at 1 kHz clk_scan
)(
    input  wire       clk,
    input  wire       clk_scan,
    input  wire       rst,
    output reg  [3:0] row,
    input  wire [3:0] col,
    output reg        hit_pulse,
    output reg        stand_pulse
);

    // Scan phase: 0..3 selects active-low row; 4 samples columns after settling
    reg [2:0] scan_step;

    // Raw active-high key states sampled during scan_step == 3'd4
    reg hit_raw_scan;
    reg stand_raw_scan;

    // Debouncer state in clk_scan domain
    reg [7:0] hit_db_cnt;
    reg       hit_db_sync_q;
    reg       hit_clean_scan;

    reg [7:0] stand_db_cnt;
    reg       stand_db_sync_q;
    reg       stand_clean_scan;

    // Synchronize debounced key levels into main clk domain for edge detection
    reg hit_sync_0, hit_sync_1, hit_prev;
    reg stand_sync_0, stand_sync_1, stand_prev;

    // Drive active-low row outputs based on scan_step
    always @(*) begin
        case (scan_step)
            3'd0, 3'd4: row = 4'b1110; // Row 0 active low
            3'd1:       row = 4'b1101; // Row 1 active low
            3'd2:       row = 4'b1011; // Row 2 active low
            3'd3:       row = 4'b0111; // Row 3 active low
            default:    row = 4'b1111;
        endcase
    end

    // Scan & debounce logic on clk_scan
    always @(posedge clk_scan or posedge rst) begin
        if (rst) begin
            scan_step        <= 3'd0;
            hit_raw_scan     <= 1'b0;
            stand_raw_scan   <= 1'b0;
            hit_db_cnt       <= 8'd0;
            hit_db_sync_q    <= 1'b0;
            hit_clean_scan   <= 1'b0;
            stand_db_cnt     <= 8'd0;
            stand_db_sync_q  <= 1'b0;
            stand_clean_scan <= 1'b0;
        end else begin
            if (scan_step == 3'd4) begin
                // Row 0 is still driven low during step 4:
                // col[0] == 0 -> Key '1' (Hit), col[1] == 0 -> Key '2' (Stand)
                hit_raw_scan   <= ~col[0];
                stand_raw_scan <= ~col[1];
                scan_step      <= 3'd0;
            end else begin
                scan_step <= scan_step + 3'd1;
            end

            // Debounce Hit (Key '1')
            if (hit_raw_scan != hit_db_sync_q) begin
                hit_db_sync_q <= hit_raw_scan;
                hit_db_cnt    <= 8'd0;
            end else if (hit_db_cnt < DEBOUNCE_TICKS) begin
                hit_db_cnt <= hit_db_cnt + 8'd1;
            end else begin
                hit_clean_scan <= hit_db_sync_q;
            end

            // Debounce Stand (Key '2')
            if (stand_raw_scan != stand_db_sync_q) begin
                stand_db_sync_q <= stand_raw_scan;
                stand_db_cnt    <= 8'd0;
            end else if (stand_db_cnt < DEBOUNCE_TICKS) begin
                stand_db_cnt <= stand_db_cnt + 8'd1;
            end else begin
                stand_clean_scan <= stand_db_sync_q;
            end
        end
    end

    // Rising-edge pulse generation synchronous to system clk
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hit_sync_0  <= 1'b0;
            hit_sync_1  <= 1'b0;
            hit_prev    <= 1'b0;
            hit_pulse   <= 1'b0;

            stand_sync_0 <= 1'b0;
            stand_sync_1 <= 1'b0;
            stand_prev   <= 1'b0;
            stand_pulse  <= 1'b0;
        end else begin
            hit_sync_0  <= hit_clean_scan;
            hit_sync_1  <= hit_sync_0;
            hit_prev    <= hit_sync_1;
            hit_pulse   <= hit_sync_1 & ~hit_prev;

            stand_sync_0 <= stand_clean_scan;
            stand_sync_1 <= stand_sync_0;
            stand_prev   <= stand_sync_1;
            stand_pulse  <= stand_sync_1 & ~stand_prev;
        end
    end

endmodule
