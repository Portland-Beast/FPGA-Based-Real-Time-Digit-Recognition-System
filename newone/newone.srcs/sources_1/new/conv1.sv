`timescale 1ns / 1ps

module conv1 (
    // System clock and reset
    input  logic                clk,
    input  logic                rst_n,

    // Input interface
    input  logic                ren_Y748,       // Start signal, falling edge begins
    input  logic [7:0]          data_in,        // Input data

    // RAM read interface
    input  logic                ram_ceb,        // RAM read enable
    input  logic [10:0]         ram_addrb,      // RAM read address
    output logic signed [11:0]  ram_dob,        // RAM read data

    // Output interface
    output logic [9:0]          raddr,          // Read original image address
    output logic                Y_ren,          // Original image read enable
    output logic                conv1_ren       // Falling edge indicates data update complete
);

    // State machine definition
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        FULL_BUF  = 2'b01,
        CALC      = 2'b10
    } state_t;

    state_t state, n_state;

    // Internal signals
    logic               ren_Y748_fft1, ren_Y748_fft2;

    // 5*28 matrix related registers
    logic [7:0]         buffer [0:139];
    logic [9:0]         buf_addr;
    logic               Y_ren_fft1;
    logic               flag_28;
    logic [4:0]         con_28;

    // 5*5 filter template registers
    logic [1:0]         con_f, con_f_fft1;
    logic [4:0]         con_24;
    logic [4:0]         con_h24;
    logic [4:0]         con_l24;
    logic signed [7:0]  weight_1 [0:24];
    logic signed [7:0]  weight_2 [0:24];
    logic signed [7:0]  weight_3 [0:24];
    logic signed [7:0]  weight_con [0:24];
    logic signed [7:0]  bias [0:2];
    logic signed [15:0] bias_con;
    logic signed [8:0]  data_con [0:24];
    logic signed [19:0] conv_out;
    logic signed [19:0] sum_group [0:4];
    logic signed [19:0] total_sum;
    logic [10:0]        waddr;
    logic               wen, wen_fft1, wen_fft2, wen_fft3;
    logic               flag_con;
    logic [10:0]        waddr_d;

    // Initialize weights and biases
    initial begin
        $readmemh("D:/weights/conv1_weight_1.txt", weight_1);
        $readmemh("D:/weights/conv1_weight_2.txt", weight_2);
        $readmemh("D:/weights/conv1_weight_3.txt", weight_3);
        $readmemh("D:/weights/conv1_bias.txt", bias);
    end

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            ren_Y748_fft1 <= 1'b0;
            ren_Y748_fft2 <= 1'b0;
        end
        else begin
            ren_Y748_fft1 <= ren_Y748;
            ren_Y748_fft2 <= ren_Y748_fft1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0)
            state <= IDLE;
        else
            state <= n_state;
    end

    always_comb begin
        if (rst_n == 1'b0)
            n_state = IDLE;
        else
            case (state)
                IDLE:     n_state = (ren_Y748_fft1 != ren_Y748_fft2 && ren_Y748_fft2 == 1) ? FULL_BUF : IDLE;
                FULL_BUF: n_state = (Y_ren_fft1 != Y_ren && Y_ren_fft1 == 1) ? CALC : FULL_BUF;
                CALC:     n_state = (waddr == 1727) ? IDLE : CALC;
                default:  n_state = IDLE;
            endcase
    end

    // Weight selection logic
    always_ff @(posedge clk) begin
        if (con_f == 2'b00) begin
            weight_con <= weight_1;
            bias_con   <= {bias[0], 8'b0};
        end
        else if (con_f == 2'b01) begin
            weight_con <= weight_2;
            bias_con   <= {bias[1], 8'b0};
        end
        else if (con_f == 2'b10) begin
            weight_con <= weight_3;
            bias_con   <= {bias[2], 8'b0};
        end
    end

    // 5*28 matrix buffer control
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0 || state == IDLE) begin
            Y_ren       <= 1'b0;
            Y_ren_fft1  <= 1'b0;
            raddr       <= '0;
            buf_addr    <= '0;
            flag_28     <= 1'b0;
            con_28      <= '0;
        end
        else begin
            Y_ren_fft1 <= Y_ren;

            if (state == FULL_BUF) begin
                Y_ren    <= 1'b1;
                buf_addr <= raddr;

                if (Y_ren == 1'b1 && raddr != 140) begin
                    raddr            <= raddr + 1'b1;
                    buffer[buf_addr] <= data_in;
                end

                if (raddr == 140) begin
                    Y_ren            <= 1'b0;
                    buffer[buf_addr] <= data_in;
                end
            end

            if (state == CALC) begin
                if (con_f == 2'b10) begin
                    flag_28 <= 1'b1;
                end

                if (flag_28 == 1'b1) begin
                    Y_ren <= 1'b1;

                    if (con_28 == 5'd27) begin
                        Y_ren <= 1'b0;
                        raddr <= raddr;
                    end
                    else
                        raddr <= raddr + 1'b1;

                    if (Y_ren == 1'b1) begin
                        if (con_28 == 5'd27) begin
                            con_28  <= '0;
                            flag_28 <= 1'b0;
                        end
                        else
                            con_28 <= con_28 + 1'b1;

                        buffer[0 + con_28]   <= buffer[28 + con_28];
                        buffer[28 + con_28]  <= buffer[56 + con_28];
                        buffer[56 + con_28]  <= buffer[84 + con_28];
                        buffer[84 + con_28]  <= buffer[112 + con_28];
                        buffer[112 + con_28] <= data_in;
                    end
                end
            end
        end
    end

    // Convolution calculation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0 || state == IDLE) begin
            con_f       <= 2'b00;
            con_f_fft1  <= 2'b00;
            con_24      <= '0;
            con_h24     <= '0;
            con_l24     <= '0;
            conv_out    <= '0;
            waddr       <= '0;
            wen         <= 1'b0;
            wen_fft1    <= 1'b0;
            wen_fft2    <= 1'b0;
            wen_fft3    <= 1'b0;
            flag_con    <= 1'b0;
            conv1_ren   <= 1'b0;
            waddr_d     <= '0;
        end
        else begin
            wen_fft1   <= wen;
            wen_fft2   <= wen_fft1;
            wen_fft3   <= wen_fft2;
            con_f_fft1 <= con_f;
            waddr_d    <= waddr;

            if (state == CALC) begin
                conv1_ren <= 1'b1;

                if (con_24 == 23 && con_f == 2'b00)
                    con_f <= 2'b01;
                if (con_24 == 23 && con_f == 2'b01)
                    con_f <= 2'b10;
                if (con_24 == 23 && con_f == 2'b10)
                    con_f <= 2'b00;

                // Extract data
                for (int i = 0; i < 5; i++) begin
                    for (int j = 0; j < 5; j++) begin
                        data_con[i*5+j] <= {1'b0, buffer[i*28 + j + con_24]};
                    end
                end

                if ((Y_ren_fft1 != Y_ren && Y_ren_fft1 == 1) || conv1_ren == 1'b0) begin
                    flag_con <= 1'b1;
                end

                if (flag_con == 1'b1) begin
                    wen <= 1'b1;

                    // Pipeline Stage 1: Partial sums
                    sum_group[0] <= data_con[0]*weight_con[0] + data_con[1]*weight_con[1] + data_con[2]*weight_con[2] + data_con[3]*weight_con[3] + data_con[4]*weight_con[4];
                    sum_group[1] <= data_con[5]*weight_con[5] + data_con[6]*weight_con[6] + data_con[7]*weight_con[7] + data_con[8]*weight_con[8] + data_con[9]*weight_con[9];
                    sum_group[2] <= data_con[10]*weight_con[10] + data_con[11]*weight_con[11] + data_con[12]*weight_con[12] + data_con[13]*weight_con[13] + data_con[14]*weight_con[14];
                    sum_group[3] <= data_con[15]*weight_con[15] + data_con[16]*weight_con[16] + data_con[17]*weight_con[17] + data_con[18]*weight_con[18] + data_con[19]*weight_con[19];
                    sum_group[4] <= data_con[20]*weight_con[20] + data_con[21]*weight_con[21] + data_con[22]*weight_con[22] + data_con[23]*weight_con[23] + data_con[24]*weight_con[24];

                    // Pipeline Stage 2: Total sum
                    total_sum <= sum_group[0] + sum_group[1] + sum_group[2] + sum_group[3] + sum_group[4];

                    // Pipeline Stage 3: Add bias and output
                    conv_out <= total_sum + bias_con;

                    if (con_24 == 23 || (con_f_fft1 == 2'b10 && con_l24 == 23))
                        con_24 <= '0;
                    else
                        con_24 <= con_24 + 1'b1;

                    if (wen == 1'b1) begin
                        waddr <= con_f_fft1 * 576 + 24 * con_h24 + con_l24;

                        if (con_l24 == 23) begin
                            con_l24 <= '0;
                            if (con_f_fft1 == 2'b10) begin
                                if (con_h24 == 23)
                                    con_h24 <= '0;
                                else
                                    con_h24 <= con_h24 + 1'b1;

                                wen      <= 1'b0;
                                flag_con <= 1'b0;
                            end
                        end
                        else
                            con_l24 <= con_l24 + 1'b1;
                    end
                end
            end
        end
    end

    // RAM instantiation
    full_cache_1024 cache_1024 (
        .dina    (conv_out[19:8]),
        .addra  (waddr_d), // Use delayed address to match pipeline
        .ena    (wen_fft3), // Use delayed write enable to match pipeline
        .doutb    (ram_dob),
        .addrb  (ram_addrb),
        .enb    (ram_ceb),
        .clka   (clk),
        .clkb   (clk)
    );

endmodule
