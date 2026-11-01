module axi_memory_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH = 256
)(
    input wire clk,
    input wire rst,

    input wire select,
    input wire write_en,

    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wdata,

    output reg [DATA_WIDTH-1:0] rdata,
    output reg ready
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            rdata <= 0;
            ready <= 0;

            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
        end

        else begin

            ready <= 0;

            if (select) begin

                if (addr < DEPTH) begin

                    if (write_en) begin
                        mem[addr] <= wdata;
                    end

                    else begin
                        rdata <= mem[addr];
                    end

                    ready <= 1;

                end

                else begin
                    rdata <= 0;
                    ready <= 1;
                end

            end

        end
    end

endmodule