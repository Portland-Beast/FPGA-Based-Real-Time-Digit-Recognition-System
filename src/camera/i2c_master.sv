module i2c_master #(
    parameter int input_clk = 50_000_000, // input clock speed from user logic in Hz
    parameter int bus_clk   = 400_000     // speed the i2c bus (scl) will run at in Hz
) (
    input  logic        clk,       // system clock
    input  logic        reset_n,   // active high reset (despite the _n suffix in original VHDL)
    input  logic        ena,       // latch in command
    input  logic [6:0]  addr,      // address of target slave
    input  logic        rw,        // '0' is write, '1' is read
    input  logic [7:0]  data_wr,   // data to write to slave
    output logic        busy,      // indicates transaction in progress
    output logic [7:0]  data_rd,   // data read from slave
    output logic        ack_error, // flag if improper acknowledge from slave
    inout  wire         sda,       // serial data output of i2c bus
    inout  wire         scl        // serial clock output of i2c bus
);

    localparam int divider = (input_clk / bus_clk) / 4; // number of clocks in 1/4 cycle of scl

    typedef enum logic [3:0] {
        READY,
        START,
        COMMAND,
        SLV_ACK1,
        WR,
        RD,
        SLV_ACK2,
        MSTR_ACK,
        STOP
    } state_t;

    state_t state, state_next;

    int count_reg, count_next;
    int bit_cnt, bit_cnt_next = 7;
    logic data_clk;
    logic data_clk_prev;
    logic scl_clk;
    logic scl_ena, scl_ena_next = 1'b0;
    logic sda_int, sda_int_next = 1'b1;
    logic sda_ena;
    logic [7:0] addr_rw, addr_next;
    logic [7:0] data_tx, data_tx_next;
    logic [7:0] data_rx, data_rx_next;
    logic stretch_reg, stretch_next;
    logic busy_r, busy_next;
    logic ack_reg, ack_next;
    logic data_clk_re, data_clk_fe;

    // register setup for i2c-bus clock and data clock
    always_ff @(posedge clk) begin
        if (reset_n) begin
            stretch_reg <= 1'b0;
            count_reg <= 0;
            data_clk_prev <= 1'b0; 
        end else begin
            stretch_reg <= stretch_next;
            data_clk_prev <= data_clk;
            count_reg <= count_next;
        end
    end

    // generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
    always_comb begin
        stretch_next = stretch_reg;
        scl_clk = 1'b0;
        data_clk = 1'b0;
        
        if (count_reg < divider) begin // 0 to divider-1
            scl_clk = 1'b0;
            data_clk = 1'b0;
        end else if (count_reg < divider * 2) begin // divider to divider*2-1
            scl_clk = 1'b0;
            data_clk = 1'b1;
        end else if (count_reg < divider * 3) begin // divider*2 to divider*3-1
            scl_clk = 1'b1;
            if (scl == 1'b0) begin // detect if slave is stretching clock
                stretch_next = 1'b1;
            end else begin
                stretch_next = 1'b0;
            end
            data_clk = 1'b1;
        end else begin // others (divider*3 to divider*4-1)
            scl_clk = 1'b1;
            data_clk = 1'b0;
        end
    end

    // register setup and reset
    always_ff @(posedge clk) begin
        if (reset_n) begin
            state <= READY;
            busy_r <= 1'b1;
            scl_ena <= 1'b0;
            sda_int <= 1'b1;
            ack_reg <= 1'b0;
            bit_cnt <= 7;
            data_rx <= 8'h00;
            addr_rw <= 8'h00; 
            data_tx <= 8'h00; 
        end else begin
            state <= state_next;
            busy_r <= busy_next;
            ack_reg <= ack_next;
            bit_cnt <= bit_cnt_next;
            scl_ena <= scl_ena_next;
            sda_int <= sda_int_next;
            addr_rw <= addr_next;
            data_tx <= data_tx_next;
            data_rx <= data_rx_next;
        end
    end

    // state machine
    always_comb begin
        state_next = state;
        busy_next = busy_r;
        ack_next = ack_reg;
        bit_cnt_next = bit_cnt;
        scl_ena_next = scl_ena;
        sda_int_next = sda_int;
        addr_next = addr_rw;
        data_tx_next = data_tx;
        data_rx_next = data_rx;

        if (data_clk_re) begin
            case (state)
                READY: begin
                    if (ena) begin
                        busy_next = 1'b1;
                        addr_next = {addr, rw};
                        data_tx_next = data_wr;
                        state_next = START;
                    end else begin
                        busy_next = 1'b0;
                    end
                end
                START: begin
                    busy_next = 1'b1;
                    sda_int_next = addr_rw[bit_cnt];
                    state_next = COMMAND;
                end
                COMMAND: begin
                    if (bit_cnt == 0) begin
                        sda_int_next = 1'b1;
                        bit_cnt_next = 7;
                        state_next = SLV_ACK1;
                    end else begin
                        bit_cnt_next = bit_cnt - 1;
                        sda_int_next = addr_rw[bit_cnt - 1];
                    end
                end
                SLV_ACK1: begin
                    if (addr_rw[0] == 1'b0) begin // write command
                        sda_int_next = data_tx[bit_cnt];
                        state_next = WR;
                    end else begin // read command
                        sda_int_next = 1'b1;
                        state_next = RD;
                    end
                end
                WR: begin
                    busy_next = 1'b1;
                    if (bit_cnt == 0) begin
                        sda_int_next = 1'b1;
                        bit_cnt_next = 7;
                        state_next = SLV_ACK2;
                    end else begin
                        bit_cnt_next = bit_cnt - 1;
                        sda_int_next = data_tx[bit_cnt - 1];
                    end
                end
                RD: begin
                    busy_next = 1'b1;
                    if (bit_cnt == 0) begin
                        if (ena && (addr_rw == {addr, rw})) begin
                            sda_int_next = 1'b0;
                        end else begin
                            sda_int_next = 1'b1;
                        end
                        bit_cnt_next = 7;
                        state_next = MSTR_ACK;
                    end else begin
                        bit_cnt_next = bit_cnt - 1;
                    end
                end
                SLV_ACK2: begin
                    if (ena) begin
                        busy_next = 1'b0;
                        addr_next = {addr, rw};
                        data_tx_next = data_wr;
                        if (addr_rw == {addr, rw}) begin
                            sda_int_next = data_wr[bit_cnt];
                            state_next = WR;
                        end else begin
                            state_next = START;
                        end
                    end else begin
                        state_next = STOP;
                    end
                end
                MSTR_ACK: begin
                    if (ena) begin
                        busy_next = 1'b0;
                        addr_next = {addr, rw};
                        data_tx_next = data_wr;
                        if (addr_rw == {addr, rw}) begin
                            sda_int_next = 1'b1;
                            state_next = RD;
                        end else begin
                            state_next = START;
                        end
                    end else begin
                        state_next = STOP;
                    end
                end
                STOP: begin
                    busy_next = 1'b0;
                    state_next = READY;
                end
                default: state_next = READY;
            endcase
        end else if (data_clk_fe) begin
            case (state)
                START: begin
                    if (scl_ena == 1'b0) begin
                        scl_ena_next = 1'b1;
                        ack_next = 1'b0;
                    end
                end
                SLV_ACK1: begin
                    if (sda != 1'b0) begin
                        ack_next = 1'b1;
                    end
                end
                RD: begin
                    data_rx_next[bit_cnt] = sda;
                end
                SLV_ACK2: begin
                    if (sda != 1'b0) begin
                        ack_next = 1'b1;
                    end
                end
                STOP: begin
                    scl_ena_next = 1'b0;
                end
                default: ;
            endcase
        end
    end

    assign data_clk_re = data_clk & ~data_clk_prev;
    assign data_clk_fe = ~data_clk & data_clk_prev;

    assign count_next = (count_reg == divider * 4 - 1) ? 0 :
                        (stretch_reg == 1'b0) ? count_reg + 1 :
                        count_reg;

    always_comb begin
        case (state)
            START: sda_ena = data_clk_prev;
            STOP:  sda_ena = ~data_clk_prev;
            default: sda_ena = sda_int;
        endcase
    end

    assign scl = (scl_ena == 1'b1 && scl_clk == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (sda_ena == 1'b0) ? 1'b0 : 1'bz;

    assign busy = busy_r;
    assign ack_error = ack_reg;
    assign data_rd = data_rx;

endmodule
