`timescale 1ns / 1ps

module keypad_scanner #(
    parameter integer DEBOUNCE_TICKS = 20, // 20 ms at 1 kHz clk_scan
    parameter [1:0]   DRAW_ROW       = 2'd3, // Row index (0..3) where key D is located
    parameter [1:0]   DRAW_COL       = 2'd3, // Col index (0..3) where key D is located
    parameter [1:0]   STAY_ROW       = 2'd2, // Row index (0..3) where key C is located
    parameter [1:0]   STAY_COL       = 2'd3  // Col index (0..3) where key C is located
)(
    input  wire       clk,
    input  wire       clk_scan,
    input  wire       rst,
    output reg  [3:0] row,
    input  wire [3:0] col,
    output reg        hit_pulse,
    output reg        stand_pulse
);

    reg [1:0] scan_row;
    reg       sample_phase; // 0 = drive row & let settle, 1 = sample col

    reg hit_raw_scan;
    reg stand_raw_scan;

    reg [7:0] hit_db_cnt;
    reg       hit_db_sync_q;
    reg       hit_clean_scan;

    reg [7:0] stand_db_cnt;
    reg       stand_db_sync_q;
    reg       stand_clean_scan;

    reg hit_sync_0, hit_sync_1, hit_prev;
    reg stand_sync_0, stand_sync_1, stand_prev;

    // Active-low row drive for current scan_row
    always @(*) begin
        case (scan_row)
            2'd0:    row = 4'b1110;
            2'd1:    row = 4'b1101;
            2'd2:    row = 4'b1011;
            2'd3:    row = 4'b0111;
            default: row = 4'b1111;
        endcase
    end

    // Scan & debounce on clk_scan
    always @(posedge clk_scan or posedge rst) begin
        if (rst) begin
            scan_row         <= 2'd0;
            sample_phase     <= 1'b0;
            hit_raw_scan     <= 1'b0;
            stand_raw_scan   <= 1'b0;
            hit_db_cnt       <= 8'd0;
            hit_db_sync_q    <= 1'b0;
            hit_clean_scan   <= 1'b0;
            stand_db_cnt     <= 8'd0;
            stand_db_sync_q  <= 1'b0;
            stand_clean_scan <= 1'b0;
        end else begin
            if (!sample_phase) begin
                sample_phase <= 1'b1;
            end else begin
                if (scan_row == DRAW_ROW) begin
                    hit_raw_scan <= ~col[DRAW_COL];
                end
                if (scan_row == STAY_ROW) begin
                    stand_raw_scan <= ~col[STAY_COL];
                end
                sample_phase <= 1'b0;
                scan_row     <= scan_row + 2'd1;
            end

            // Debounce Draw (hit_pulse)
            if (hit_raw_scan != hit_db_sync_q) begin
                hit_db_sync_q <= hit_raw_scan;
                hit_db_cnt    <= 8'd0;
            end else if (hit_db_cnt < DEBOUNCE_TICKS) begin
                hit_db_cnt <= hit_db_cnt + 8'd1;
            end else begin
                hit_clean_scan <= hit_db_sync_q;
            end

            // Debounce Stay (stand_pulse)
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

    // Synchronize into system clk domain and generate single-cycle pulses
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
            hit_sync_0   <= hit_clean_scan;
            hit_sync_1   <= hit_sync_0;
            hit_prev     <= hit_sync_1;
            hit_pulse    <= hit_sync_1 & ~hit_prev;

            stand_sync_0 <= stand_clean_scan;
            stand_sync_1 <= stand_sync_0;
            stand_prev   <= stand_sync_1;
            stand_pulse  <= stand_sync_1 & ~stand_prev;
        end
    end

endmodule
