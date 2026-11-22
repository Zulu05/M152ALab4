module debouncer #(
    parameter MAX_COUNT = 20'd1_000_000 // 10ms at 100MHz
)(
    input  wire clk,
    input  wire noisy_in,
    output reg  clean_out = 1'b0
);

    reg [1:0] sync_reg = 2'b00;
    reg [19:0] counter = 20'd0;

    // 2-stage synchronizer to prevent metastability
    always @(posedge clk) begin
        sync_reg <= {sync_reg[0], noisy_in};
    end

    // Debounce timer
    always @(posedge clk) begin
        if (sync_reg[1] == clean_out) begin
            counter <= 20'd0;
        end else begin
            if (counter == MAX_COUNT - 1) begin
                clean_out <= sync_reg[1];
                counter   <= 20'd0;
            end else begin
                counter <= counter + 20'd1;
            end
        end
    end

endmodule
