module adaptive_arbiter (
    input wire clk,
    input wire rst,
    input wire [1:0] req,
    input wire mode,
    input wire done,

    // New starvation inputs
    input wire [1:0] starved,

    output reg [1:0] grant
);

reg last_grant;

always @(posedge clk or posedge rst) begin

    if (rst) begin
        grant <= 2'b00;
        last_grant <= 1'b1;
    end

    else begin

        // Maintain the current grant until transaction completes
        if (grant != 2'b00) begin

            if (done) begin
                last_grant <= grant[0] ? 1'b0 : 1'b1;
                grant <= 2'b00;
            end

        end

        // Select a master when the arbiter is idle
        else begin

            // Case 1: Only Master 0 is starved
            if (starved == 2'b01 && req[0]) begin
                grant <= 2'b01;
            end

            // Case 2: Only Master 1 is starved
            else if (starved == 2'b10 && req[1]) begin
                grant <= 2'b10;
            end

            // Case 3: Both masters are starved
            else if (starved == 2'b11) begin

                if (req[0] && req[1]) begin
                    if (last_grant == 1'b0)
                        grant <= 2'b10;
                    else
                        grant <= 2'b01;
                end
                else if (req[0])
                    grant <= 2'b01;
                else if (req[1])
                    grant <= 2'b10;
                else
                    grant <= 2'b00;

            end

            // Case 4: Normal arbitration
            else begin

                if (mode == 1'b0) begin

                    // Fixed Priority: Master 0 first
                    if (req[0])
                        grant <= 2'b01;
                    else if (req[1])
                        grant <= 2'b10;
                    else
                        grant <= 2'b00;

                end

                else begin

                    // Round Robin
                    if (req[0] && req[1]) begin
                        if (last_grant == 1'b0)
                            grant <= 2'b10;
                        else
                            grant <= 2'b01;
                    end
                    else if (req[0])
                        grant <= 2'b01;
                    else if (req[1])
                        grant <= 2'b10;
                    else
                        grant <= 2'b00;

                end
            end
        end
    end
end

endmodule