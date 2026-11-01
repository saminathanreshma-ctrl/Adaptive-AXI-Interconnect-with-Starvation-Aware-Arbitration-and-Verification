module axi_interconnect_top (
    input wire clk,
    input wire rst,
    input wire [1:0] req,
    input wire mode,
    input wire done,
    input wire [31:0] m0_addr,
    input wire m0_write,
    input wire [31:0] m0_wdata,
    input wire [31:0] m1_addr,
    input wire m1_write,
    input wire [31:0] m1_wdata,
    output wire [1:0] grant,
    output wire [31:0] rdata,
    output wire ready,
    output wire addr_valid
);

reg [31:0] selected_addr;
reg selected_write;
reg [31:0] selected_wdata;

wire [1:0] slave_sel;
wire [31:0] s0_rdata, s1_rdata;
wire s0_ready, s1_ready;
wire s0_select, s1_select;

// New starvation signals
wire [7:0] wait_count0, wait_count1;
wire starved0, starved1;
wire [1:0] starved;

// Combine starvation flags
assign starved = {starved1, starved0};

// 1. Starvation Monitor
starvation_monitor #(
    .COUNT_WIDTH(8),
    .THRESHOLD(8)
) MONITOR (
    .clk(clk),
    .rst(rst),
    .req(req),
    .grant(grant),
    .wait_count0(wait_count0),
    .wait_count1(wait_count1),
    .starved0(starved0),
    .starved1(starved1)
);

// 2. Adaptive Arbiter
adaptive_arbiter ARBITER (
    .clk(clk),
    .rst(rst),
    .req(req),
    .mode(mode),
    .done(done),
    .starved(starved),
    .grant(grant)
);

// 3. Select master transaction
always @(*) begin

    selected_addr = 32'b0;
    selected_write = 1'b0;
    selected_wdata = 32'b0;

    case (grant)

        2'b01: begin
            selected_addr = m0_addr;
            selected_write = m0_write;
            selected_wdata = m0_wdata;
        end

        2'b10: begin
            selected_addr = m1_addr;
            selected_write = m1_write;
            selected_wdata = m1_wdata;
        end

        default: begin
            selected_addr = 32'b0;
            selected_write = 1'b0;
            selected_wdata = 32'b0;
        end

    endcase
end

// 4. Address Decoder
axi_address_decoder DECODER (
    .addr(selected_addr),
    .slave_sel(slave_sel),
    .addr_valid(addr_valid)
);

// 5. Memory Slave Selection
assign s0_select = (grant != 2'b00) && (slave_sel == 2'b01);
assign s1_select = (grant != 2'b00) && (slave_sel == 2'b10);

// 6. Memory Slave 0
axi_memory_slave SLAVE0 (
    .clk(clk),
    .rst(rst),
    .select(s0_select),
    .write_en(selected_write),
    .addr(selected_addr[7:0]),
    .wdata(selected_wdata),
    .rdata(s0_rdata),
    .ready(s0_ready)
);

// 7. Memory Slave 1
axi_memory_slave SLAVE1 (
    .clk(clk),
    .rst(rst),
    .select(s1_select),
    .write_en(selected_write),
    .addr(selected_addr[7:0]),
    .wdata(selected_wdata),
    .rdata(s1_rdata),
    .ready(s1_ready)
);

// 8. Read Data Selection
assign rdata = (slave_sel == 2'b01) ? s0_rdata :
               (slave_sel == 2'b10) ? s1_rdata : 32'b0;

// 9. Ready Signal
assign ready = s0_ready | s1_ready;

endmodule