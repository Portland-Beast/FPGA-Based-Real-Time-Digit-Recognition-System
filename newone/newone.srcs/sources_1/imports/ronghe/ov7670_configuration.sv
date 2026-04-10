module ov7670_configuration (
    input  logic        clk,
    input  logic        rst,
    input  logic [3:0]  edge_in, // Renamed from edge to avoid keyword conflict
    inout  wire         sda,
    inout  wire         scl,
    input  logic        start,
    output logic        done,
    output logic        ack_err,
    output logic        ov7670_reset,
    output logic        config_finished,
    output logic [7:0]  reg_value
);

    localparam int C_ARTY_A7_CLK_FREQ = 100000000; // 100 MHz

    logic i2c_ena;
    logic [6:0] i2c_addr;
    logic i2c_rw;
    logic i2c_busy;
    logic [7:0] i2c_rdata;
    logic [7:0] i2c_wdata;
    logic i2c_ack_err;

    ov7670_fsm ov7670_fsm_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .i2c_busy(i2c_busy),
        .i2c_rdata(i2c_rdata),
        .i2c_addr(i2c_addr),
        .i2c_wdata(i2c_wdata),
        .i2c_ena(i2c_ena),
        .i2c_rw(i2c_rw),
        .ov7670_reset(ov7670_reset),
        .reg_value(reg_value),
        .config_finished(config_finished),
        .done(done)
    );

    i2c_master #(
        .input_clk(C_ARTY_A7_CLK_FREQ)
    ) i2c_master_inst (
        .clk(clk),
        .reset_n(rst), // Following VHDL mapping
        .ena(i2c_ena),
        .addr(i2c_addr),
        .rw(i2c_rw),
        .data_wr(i2c_wdata),
        .busy(i2c_busy),
        .data_rd(i2c_rdata),
        .ack_error(i2c_ack_err),
        .sda(sda),
        .scl(scl)
    );

    assign ack_err = i2c_ack_err;

endmodule
