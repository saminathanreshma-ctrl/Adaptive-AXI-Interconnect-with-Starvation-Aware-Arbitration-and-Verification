module starvation_monitor #(
    parameter COUNT_WIDTH = 8,
    parameter THRESHOLD = 8
)(
    input wire clk,
    input wire rst,

    input wire [1:0] req,
    input wire [1:0] grant,

    output reg [COUNT_WIDTH-1:0] wait_count0,
    output reg [COUNT_WIDTH-1:0] wait_count1,

    output reg starved0,
    output reg starved1
);

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            wait_count0 <= 0;
            wait_count1 <= 0;
            starved0 <= 0;
            starved1 <= 0;
        end

        else begin

            // Master 0 monitoring
            if (!req[0] || grant[0]) begin
                wait_count0 <= 0;
                starved0 <= 0;
            end
            else if (wait_count0 < THRESHOLD) begin
                wait_count0 <= wait_count0 + 1'b1;

                if (wait_count0 >= THRESHOLD - 1)
                    starved0 <= 1'b1;
            end

            // Master 1 monitoring
            if (!req[1] || grant[1]) begin
                wait_count1 <= 0;
                starved1 <= 0;
            end
            else if (wait_count1 < THRESHOLD) begin
                wait_count1 <= wait_count1 + 1'b1;

                if (wait_count1 >= THRESHOLD - 1)
                    starved1 <= 1'b1;
            end

        end
    end

endmodule