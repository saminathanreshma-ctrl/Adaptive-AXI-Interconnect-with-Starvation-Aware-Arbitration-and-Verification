module axi_address_decoder (

    input wire [31:0] addr,

    output reg [1:0] slave_sel,

    output reg addr_valid

);

    always @(*) begin

        // Default: No slave selected
        slave_sel = 2'b00;
        addr_valid = 1'b0;

        // Select Slave 0
        if (addr >= 32'h00000000 &&
            addr <= 32'h00000FFF) begin

            slave_sel = 2'b01;
            addr_valid = 1'b1;

        end

        // Select Slave 1
        else if (addr >= 32'h00001000 &&
                 addr <= 32'h00001FFF) begin

            slave_sel = 2'b10;
            addr_valid = 1'b1;

        end

        // Invalid address
        else begin

            slave_sel = 2'b00;
            addr_valid = 1'b0;

        end

    end

endmodule