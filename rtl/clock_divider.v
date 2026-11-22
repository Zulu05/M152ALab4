module clock_divider #(
    parameter HALF_PERIOD = 16'd50_000 // 100MHz / (2 * 50,000) = 1kHz
)(
    input  wire clk,
    input  wire rst,
    output reg  clk_1khz
);

    reg [15:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter  <= 16'd0;
            clk_1khz <= 1'b0;
        end else begin
            if (counter == HALF_PERIOD - 1) begin
                counter  <= 16'd0;
                clk_1khz <= ~clk_1khz;
            end else begin
                counter <= counter + 16'd1;
            end
        end
    end

endmodule
