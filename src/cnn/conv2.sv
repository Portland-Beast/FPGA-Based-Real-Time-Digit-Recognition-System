`timescale 1ns/ 1ps

// Convolution layer 2 module
module conv2( 
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ren_Y748,      // Start signal, falling edge starts
    input  logic signed [11:0] data_in,
    input  logic        ram_ceb,
    input  logic [7:0]  ram_addrb,
    output logic [8:0]  raddr1,        // Read address for original image 
    output logic        Y_ren,         // Original image read enable
    output logic        conv1_ren,     // Falling edge indicates data update complete
    output logic signed [11:0] ram_dob
);

    // State machine definition
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        FULL_BUF = 2'b01,
        CALC     = 2'b10
    } state_t;
    
    state_t state, n_state;
    
    logic ren_Y748_fft1, ren_Y748_fft2;
    
    logic [0:0] wea;
    logic conv2_ren, conv2_ren_fft1, re_start, re_start_fft1, flag_wait;
    logic [1:0] cnt_3;
    logic [2:0] cnt_8;
    logic [8:0] raddr;
    
    logic signed [11:0] buffer [0:59];   // 5*12 matrix
    logic [8:0]  buf_addr;               // raddr read address delayed by one clock
    logic        Y_ren_fft1;             // Original image read enable delayed
    logic        flag_12;                // Set when cnt_f=2, reset when con_12=12
    logic [3:0]  con_12;                 // 0-11
    
    logic [1:0] con_f, con_f_fft1, con_f_fft2, con_f_fft3;
    logic [2:0] con_8;        // 0-7
    logic [4:0] con_h8, con8h;  // 0-23 con8h for result, conh8 for intermediate
    logic [2:0] con_l8;       // 0-7
    
    // Weight and bias arrays
    logic signed [7:0] weight_1 [0:24];
    logic signed [7:0] weight_2 [0:24];
    logic signed [7:0] weight_3 [0:24];
    logic signed [7:0] weight_4 [0:24];
    logic signed [7:0] weight_5 [0:24];
    logic signed [7:0] weight_6 [0:24];
    logic signed [7:0] weight_7 [0:24];
    logic signed [7:0] weight_8 [0:24];
    logic signed [7:0] weight_9 [0:24];
    logic signed [7:0] weight_con [0:24];
    logic signed [7:0] bias [0:2];
    
    logic signed [11:0] exp_bias [0:2];
    logic signed [11:0] data_con [0:24];
    logic signed [19:0] conv_out;
    // logic signed [19:0] conv_out_reg; // Removed, replaced by pipeline
    logic signed [19:0] conv_out_add0;
    logic signed [19:0] conv_out_add1;
    logic signed [19:0] add;
    logic signed [11:0] data_out;
    
    logic [7:0] conv_raddr;
    logic [7:0] conv_addr;
    logic [7:0] waddr;
    logic [2:0] con_wh8, con_wl8;  // Calculate output address
    logic [1:0] con_w3;            // Calculate output address
    logic       wen, wen_fft1, wen_fft2, wen_fft3;     // conv2 modified
    logic       write, write_flag, waddr_flag;  // conv2 write RAM enable
    logic       flag_con;          // Y_ren falling edge triggers calculation start
    logic [7:0] conv_addr_d;       // Delayed address for pipeline alignment

    // Pipeline registers
    logic signed [19:0] sum_group [0:4];
    logic signed [19:0] total_sum;
    
    // Load weights and biases from files
    initial begin
        $readmemh("D:/weights/conv2_weight_11.txt", weight_1);
        $readmemh("D:/weights/conv2_weight_12.txt", weight_2);
        $readmemh("D:/weights/conv2_weight_13.txt", weight_3);
        $readmemh("D:/weights/conv2_weight_21.txt", weight_4);
        $readmemh("D:/weights/conv2_weight_22.txt", weight_5);
        $readmemh("D:/weights/conv2_weight_23.txt", weight_6);
        $readmemh("D:/weights/conv2_weight_31.txt", weight_7);
        $readmemh("D:/weights/conv2_weight_32.txt", weight_8);
        $readmemh("D:/weights/conv2_weight_33.txt", weight_9);
        $readmemh("D:/weights/conv2_bias.txt", bias);
    end
    
    // State machine implementation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= n_state;
    end
    
    always_comb begin
        if (!rst_n)
            n_state = IDLE;
        else
            case(state)
                IDLE:     n_state = (re_start_fft1 != re_start && re_start_fft1 == 1) ? FULL_BUF : IDLE;
                FULL_BUF: n_state = (Y_ren_fft1 != Y_ren && Y_ren_fft1 == 1) ? CALC : FULL_BUF;
                CALC:     n_state = (conv_addr == 191) ? IDLE : CALC;
                default:  n_state = IDLE;
            endcase
    end
    
    assign raddr1 = raddr + cnt_3 * 144;
    
    assign exp_bias[0] = (bias[0][7] == 1) ? {4'b1111, bias[0]} : {4'b0000, bias[0]};
    assign exp_bias[1] = (bias[1][7] == 1) ? {4'b1111, bias[1]} : {4'b0000, bias[1]};
    assign exp_bias[2] = (bias[2][7] == 1) ? {4'b1111, bias[2]} : {4'b0000, bias[2]};
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_3          <= 2'b00;
            re_start       <= 1'b0;
            re_start_fft1  <= 1'b0;
            conv2_ren_fft1 <= 1'b0;
            cnt_8          <= 3'b000;
            flag_wait      <= 1'b0;
            ren_Y748_fft1  <= 1'b0;
            ren_Y748_fft2  <= 1'b0;
            conv1_ren      <= 1'b0;
        end
        else begin
            ren_Y748_fft1  <= ren_Y748;
            ren_Y748_fft2  <= ren_Y748_fft1;
            re_start_fft1  <= re_start;
            conv2_ren_fft1 <= conv2_ren;
            
            // conv1_ren control
            if (conv2_ren_fft1 != conv2_ren && conv2_ren_fft1 == 1 && cnt_3 == 2'b10)
                conv1_ren <= 1'b0;
            else
                conv1_ren <= 1'b1;
            
            // cnt_3 reset
            if (conv2_ren_fft1 != conv2_ren && conv2_ren_fft1 == 1 && cnt_3 == 2'b10)
                cnt_3 <= 2'b00;
            
            // re_start control
            if (ren_Y748_fft1 != ren_Y748_fft2 && ren_Y748_fft2 == 1)
                re_start <= 1'b0;
            else if (conv2_ren_fft1 != conv2_ren && conv2_ren_fft1 == 1 && cnt_3 != 2'b10)
                flag_wait <= 1'b1;
            else
                re_start <= 1'b1;
            
            // Wait counter
            if (flag_wait == 1'b1) begin
                if (cnt_8 != 7)
                    cnt_8 <= cnt_8 + 1;
                else begin
                    re_start  <= 1'b0;
                    cnt_3     <= cnt_3 + 2'b01;
                    cnt_8     <= 0;
                    flag_wait <= 1'b0;
                end
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (cnt_3 == 0) begin
            if (con_f == 2'b00) begin
                weight_con[0]  <= weight_1[0];  weight_con[1]  <= weight_1[1];  weight_con[2]  <= weight_1[2];  weight_con[3]  <= weight_1[3];  weight_con[4]  <= weight_1[4];
                weight_con[5]  <= weight_1[5];  weight_con[6]  <= weight_1[6];  weight_con[7]  <= weight_1[7];  weight_con[8]  <= weight_1[8];  weight_con[9]  <= weight_1[9];
                weight_con[10] <= weight_1[10]; weight_con[11] <= weight_1[11]; weight_con[12] <= weight_1[12]; weight_con[13] <= weight_1[13]; weight_con[14] <= weight_1[14];
                weight_con[15] <= weight_1[15]; weight_con[16] <= weight_1[16]; weight_con[17] <= weight_1[17]; weight_con[18] <= weight_1[18]; weight_con[19] <= weight_1[19];
                weight_con[20] <= weight_1[20]; weight_con[21] <= weight_1[21]; weight_con[22] <= weight_1[22]; weight_con[23] <= weight_1[23]; weight_con[24] <= weight_1[24];
            end
            if (con_f == 2'b01) begin
                weight_con[0]  <= weight_4[0];  weight_con[1]  <= weight_4[1];  weight_con[2]  <= weight_4[2];  weight_con[3]  <= weight_4[3];  weight_con[4]  <= weight_4[4];
                weight_con[5]  <= weight_4[5];  weight_con[6]  <= weight_4[6];  weight_con[7]  <= weight_4[7];  weight_con[8]  <= weight_4[8];  weight_con[9]  <= weight_4[9];
                weight_con[10] <= weight_4[10]; weight_con[11] <= weight_4[11]; weight_con[12] <= weight_4[12]; weight_con[13] <= weight_4[13]; weight_con[14] <= weight_4[14];
                weight_con[15] <= weight_4[15]; weight_con[16] <= weight_4[16]; weight_con[17] <= weight_4[17]; weight_con[18] <= weight_4[18]; weight_con[19] <= weight_4[19];
                weight_con[20] <= weight_4[20]; weight_con[21] <= weight_4[21]; weight_con[22] <= weight_4[22]; weight_con[23] <= weight_4[23]; weight_con[24] <= weight_4[24];
            end
            if (con_f == 2'b10) begin
                weight_con[0]  <= weight_7[0];  weight_con[1]  <= weight_7[1];  weight_con[2]  <= weight_7[2];  weight_con[3]  <= weight_7[3];  weight_con[4]  <= weight_7[4];
                weight_con[5]  <= weight_7[5];  weight_con[6]  <= weight_7[6];  weight_con[7]  <= weight_7[7];  weight_con[8]  <= weight_7[8];  weight_con[9]  <= weight_7[9];
                weight_con[10] <= weight_7[10]; weight_con[11] <= weight_7[11]; weight_con[12] <= weight_7[12]; weight_con[13] <= weight_7[13]; weight_con[14] <= weight_7[14];
                weight_con[15] <= weight_7[15]; weight_con[16] <= weight_7[16]; weight_con[17] <= weight_7[17]; weight_con[18] <= weight_7[18]; weight_con[19] <= weight_7[19];
                weight_con[20] <= weight_7[20]; weight_con[21] <= weight_7[21]; weight_con[22] <= weight_7[22]; weight_con[23] <= weight_7[23]; weight_con[24] <= weight_7[24];
            end
        end
        if (cnt_3 == 1) begin
            if (con_f == 2'b00) begin
                weight_con[0]  <= weight_2[0];  weight_con[1]  <= weight_2[1];  weight_con[2]  <= weight_2[2];  weight_con[3]  <= weight_2[3];  weight_con[4]  <= weight_2[4];
                weight_con[5]  <= weight_2[5];  weight_con[6]  <= weight_2[6];  weight_con[7]  <= weight_2[7];  weight_con[8]  <= weight_2[8];  weight_con[9]  <= weight_2[9];
                weight_con[10] <= weight_2[10]; weight_con[11] <= weight_2[11]; weight_con[12] <= weight_2[12]; weight_con[13] <= weight_2[13]; weight_con[14] <= weight_2[14];
                weight_con[15] <= weight_2[15]; weight_con[16] <= weight_2[16]; weight_con[17] <= weight_2[17]; weight_con[18] <= weight_2[18]; weight_con[19] <= weight_2[19];
                weight_con[20] <= weight_2[20]; weight_con[21] <= weight_2[21]; weight_con[22] <= weight_2[22]; weight_con[23] <= weight_2[23]; weight_con[24] <= weight_2[24];
            end
            if (con_f == 2'b01) begin
                weight_con[0]  <= weight_5[0];  weight_con[1]  <= weight_5[1];  weight_con[2]  <= weight_5[2];  weight_con[3]  <= weight_5[3];  weight_con[4]  <= weight_5[4];
                weight_con[5]  <= weight_5[5];  weight_con[6]  <= weight_5[6];  weight_con[7]  <= weight_5[7];  weight_con[8]  <= weight_5[8];  weight_con[9]  <= weight_5[9];
                weight_con[10] <= weight_5[10]; weight_con[11] <= weight_5[11]; weight_con[12] <= weight_5[12]; weight_con[13] <= weight_5[13]; weight_con[14] <= weight_5[14];
                weight_con[15] <= weight_5[15]; weight_con[16] <= weight_5[16]; weight_con[17] <= weight_5[17]; weight_con[18] <= weight_5[18]; weight_con[19] <= weight_5[19];
                weight_con[20] <= weight_5[20]; weight_con[21] <= weight_5[21]; weight_con[22] <= weight_5[22]; weight_con[23] <= weight_5[23]; weight_con[24] <= weight_5[24];
            end
            if (con_f == 2'b10) begin
                weight_con[0]  <= weight_8[0];  weight_con[1]  <= weight_8[1];  weight_con[2]  <= weight_8[2];  weight_con[3]  <= weight_8[3];  weight_con[4]  <= weight_8[4];
                weight_con[5]  <= weight_8[5];  weight_con[6]  <= weight_8[6];  weight_con[7]  <= weight_8[7];  weight_con[8]  <= weight_8[8];  weight_con[9]  <= weight_8[9];
                weight_con[10] <= weight_8[10]; weight_con[11] <= weight_8[11]; weight_con[12] <= weight_8[12]; weight_con[13] <= weight_8[13]; weight_con[14] <= weight_8[14];
                weight_con[15] <= weight_8[15]; weight_con[16] <= weight_8[16]; weight_con[17] <= weight_8[17]; weight_con[18] <= weight_8[18]; weight_con[19] <= weight_8[19];
                weight_con[20] <= weight_8[20]; weight_con[21] <= weight_8[21]; weight_con[22] <= weight_8[22]; weight_con[23] <= weight_8[23]; weight_con[24] <= weight_8[24];
            end
        end
        if (cnt_3 == 2) begin
            if (con_f == 2'b00) begin
                weight_con[0]  <= weight_3[0];  weight_con[1]  <= weight_3[1];  weight_con[2]  <= weight_3[2];  weight_con[3]  <= weight_3[3];  weight_con[4]  <= weight_3[4];
                weight_con[5]  <= weight_3[5];  weight_con[6]  <= weight_3[6];  weight_con[7]  <= weight_3[7];  weight_con[8]  <= weight_3[8];  weight_con[9]  <= weight_3[9];
                weight_con[10] <= weight_3[10]; weight_con[11] <= weight_3[11]; weight_con[12] <= weight_3[12]; weight_con[13] <= weight_3[13]; weight_con[14] <= weight_3[14];
                weight_con[15] <= weight_3[15]; weight_con[16] <= weight_3[16]; weight_con[17] <= weight_3[17]; weight_con[18] <= weight_3[18]; weight_con[19] <= weight_3[19];
                weight_con[20] <= weight_3[20]; weight_con[21] <= weight_3[21]; weight_con[22] <= weight_3[22]; weight_con[23] <= weight_3[23]; weight_con[24] <= weight_3[24];
            end
            if (con_f == 2'b01) begin
                weight_con[0]  <= weight_6[0];  weight_con[1]  <= weight_6[1];  weight_con[2]  <= weight_6[2];  weight_con[3]  <= weight_6[3];  weight_con[4]  <= weight_6[4];
                weight_con[5]  <= weight_6[5];  weight_con[6]  <= weight_6[6];  weight_con[7]  <= weight_6[7];  weight_con[8]  <= weight_6[8];  weight_con[9]  <= weight_6[9];
                weight_con[10] <= weight_6[10]; weight_con[11] <= weight_6[11]; weight_con[12] <= weight_6[12]; weight_con[13] <= weight_6[13]; weight_con[14] <= weight_6[14];
                weight_con[15] <= weight_6[15]; weight_con[16] <= weight_6[16]; weight_con[17] <= weight_6[17]; weight_con[18] <= weight_6[18]; weight_con[19] <= weight_6[19];
                weight_con[20] <= weight_6[20]; weight_con[21] <= weight_6[21]; weight_con[22] <= weight_6[22]; weight_con[23] <= weight_6[23]; weight_con[24] <= weight_6[24];
            end
            if (con_f == 2'b10) begin
                weight_con[0]  <= weight_9[0];  weight_con[1]  <= weight_9[1];  weight_con[2]  <= weight_9[2];  weight_con[3]  <= weight_9[3];  weight_con[4]  <= weight_9[4];
                weight_con[5]  <= weight_9[5];  weight_con[6]  <= weight_9[6];  weight_con[7]  <= weight_9[7];  weight_con[8]  <= weight_9[8];  weight_con[9]  <= weight_9[9];
                weight_con[10] <= weight_9[10]; weight_con[11] <= weight_9[11]; weight_con[12] <= weight_9[12]; weight_con[13] <= weight_9[13]; weight_con[14] <= weight_9[14];
                weight_con[15] <= weight_9[15]; weight_con[16] <= weight_9[16]; weight_con[17] <= weight_9[17]; weight_con[18] <= weight_9[18]; weight_con[19] <= weight_9[19];
                weight_con[20] <= weight_9[20]; weight_con[21] <= weight_9[21]; weight_con[22] <= weight_9[22]; weight_con[23] <= weight_9[23]; weight_con[24] <= weight_9[24];
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || state == IDLE) begin
            Y_ren     <= 1'b0;
            Y_ren_fft1 <= 1'b0;
            raddr     <= 10'd0;
            buf_addr  <= 10'd0;
            flag_12   <= 1'b0;
            con_12    <= 4'b0000;
        end
        else begin
            Y_ren_fft1 <= Y_ren;
            
            if (state == FULL_BUF) begin
                Y_ren    <= 1'b1;
                buf_addr <= raddr;
                
                if (Y_ren == 1'b1 && raddr != 60) begin
                    raddr          <= raddr + 1'b1;
                    buffer[buf_addr] <= data_in;
                end
                
                if (raddr == 60) begin
                    Y_ren            <= 1'b0;
                    buffer[buf_addr] <= data_in;
                end
            end
            
            if (state == CALC) begin
                if (con_f == 2'b10)
                    flag_12 <= 1'b1;
                
                if (flag_12 == 1'b1) begin
                    Y_ren <= 1'b1;
                    
                    if (con_12 == 4'd11)
                        Y_ren <= 1'b0;
                    
                    if (con_12 != 4'd11)
                        raddr <= raddr + 1'b1;
                    
                    if (Y_ren == 1'b1) begin
                        if (con_12 == 4'd11) begin
                            con_12  <= 4'b0000;
                            flag_12 <= 1'b0;
                        end
                        else
                            con_12 <= con_12 + 1'b1;
                        
                        buffer[0 + con_12]  <= buffer[12 + con_12];
                        buffer[12 + con_12] <= buffer[24 + con_12];
                        buffer[24 + con_12] <= buffer[36 + con_12];
                        buffer[36 + con_12] <= buffer[48 + con_12];
                        buffer[48 + con_12] <= data_in;
                    end
                end
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || state == IDLE) begin
            con_f      <= 2'b00;
            con_f_fft1 <= 2'b00;
            con_f_fft2 <= 2'b00;
            con_f_fft3 <= 2'b00;
            con_8      <= 3'b000;
            con_h8     <= 5'b000;
            con_l8     <= 3'b000;
            conv_out   <= 20'd0;
            conv_addr  <= 8'd0;
            wen        <= 1'b0;
            wen_fft1   <= 1'b0;
            flag_con   <= 1'b0;
            conv2_ren  <= 1'b0;
        end
        else begin
            wen_fft1   <= wen;
            con_f_fft1 <= con_f;
            con_f_fft2 <= con_f_fft1;
            con_f_fft3 <= con_f_fft2;
            
            if (state == CALC) begin
                conv2_ren <= 1'b1;
                
                if (con_8 == 7 && con_f == 2'b00)
                    con_f <= 2'b01;
                
                if (con_8 == 7 && con_f == 2'b01)
                    con_f <= 2'b10;
                
                if (con_8 == 7 && con_f == 2'b10)
                    con_f <= 2'b00;
                
                data_con[0]  <= buffer[0 + con_8];  data_con[1]  <= buffer[1 + con_8];  data_con[2]  <= buffer[2 + con_8];  data_con[3]  <= buffer[3 + con_8];  data_con[4]  <= buffer[4 + con_8];
                data_con[5]  <= buffer[12 + con_8]; data_con[6]  <= buffer[13 + con_8]; data_con[7]  <= buffer[14 + con_8]; data_con[8]  <= buffer[15 + con_8]; data_con[9]  <= buffer[16 + con_8];
                data_con[10] <= buffer[24 + con_8]; data_con[11] <= buffer[25 + con_8]; data_con[12] <= buffer[26 + con_8]; data_con[13] <= buffer[27 + con_8]; data_con[14] <= buffer[28 + con_8];
                data_con[15] <= buffer[36 + con_8]; data_con[16] <= buffer[37 + con_8]; data_con[17] <= buffer[38 + con_8]; data_con[18] <= buffer[39 + con_8]; data_con[19] <= buffer[40 + con_8];
                data_con[20] <= buffer[48 + con_8]; data_con[21] <= buffer[49 + con_8]; data_con[22] <= buffer[50 + con_8]; data_con[23] <= buffer[51 + con_8]; data_con[24] <= buffer[52 + con_8];
                
                if ((Y_ren_fft1 != Y_ren && Y_ren_fft1 == 1) || conv2_ren == 1'b0)
                    flag_con <= 1'b1;
                
                if (flag_con == 1'b1) begin
                    wen <= 1'b1;
                    
                    // Pipeline Stage 1: Partial sums (5 groups of 5)
                    sum_group[0] <= data_con[0] * weight_con[0] + data_con[1] * weight_con[1] + data_con[2] * weight_con[2] + data_con[3] * weight_con[3] + data_con[4] * weight_con[4];
                    sum_group[1] <= data_con[5] * weight_con[5] + data_con[6] * weight_con[6] + data_con[7] * weight_con[7] + data_con[8] * weight_con[8] + data_con[9] * weight_con[9];
                    sum_group[2] <= data_con[10] * weight_con[10] + data_con[11] * weight_con[11] + data_con[12] * weight_con[12] + data_con[13] * weight_con[13] + data_con[14] * weight_con[14];
                    sum_group[3] <= data_con[15] * weight_con[15] + data_con[16] * weight_con[16] + data_con[17] * weight_con[17] + data_con[18] * weight_con[18] + data_con[19] * weight_con[19];
                    sum_group[4] <= data_con[20] * weight_con[20] + data_con[21] * weight_con[21] + data_con[22] * weight_con[22] + data_con[23] * weight_con[23] + data_con[24] * weight_con[24];
                    
                    // Pipeline Stage 2: Sum of groups
                    total_sum <= sum_group[0] + sum_group[1] + sum_group[2] + sum_group[3] + sum_group[4];

                    // Pipeline Stage 3: Register output
                    conv_out <= total_sum;

                    if (con_8 == 7 || (con_f_fft1 == 2'b10 && con_l8 == 7))
                        con_8 <= 0;
                    else
                        con_8 <= con_8 + 1'b1;
                    
                    if (wen == 1'b1) begin
                        conv_addr <= con_h8 * 8 + con_l8;
                        
                        if (con_l8 == 7) begin
                            con_l8 <= 0;
                            
                            if (con_h8 == 23)
                                con_h8 <= 0;
                            else
                                con_h8 <= con_h8 + 1'b1;
                            
                            if (con_f_fft1 == 2'b10) begin
                                wen      <= 1'b0;
                                flag_con <= 1'b0;
                            end
                        end
                        else
                            con_l8 <= con_l8 + 1'b1;
                    end
                end
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out   <= 12'd0;
            waddr      <= 8'd0;
            conv_raddr <= 8'd0;
            write      <= 1'b0;
            write_flag <= 1'b0;
            waddr_flag <= 1'b0;
            con8h      <= 5'b00000;
            add        <= 20'd0;
            con_wh8    <= 3'b000;
            con_wl8    <= 3'b000;
            con_w3     <= 2'b00;
            wen_fft2   <= 1'b0;
            wen_fft3   <= 1'b0;
            conv_addr_d <= 8'd0;
        end
        else begin
            wen_fft2 <= wen_fft1;
            wen_fft3 <= wen_fft2; // Delay wen_fft2 to match new pipeline depth
            conv_addr_d <= conv_addr; // Delay address to match data pipeline

            if (cnt_3 == 2 && state == CALC)
                write_flag <= 1'b1;
            
            if (write_flag == 1'b0) begin
            end
            else begin
                write <= waddr_flag;
                
                if (con_8 + con8h * 8 > 191)
                    conv_raddr <= 191;
                else
                    conv_raddr <= con_8 + con8h * 8;
                
                if (con_8 == 7)
                    con8h <= con8h + 1;
                
                if (wen_fft3) // Use delayed wen signal (Stage 3)
                    add <= conv_out_add0 + conv_out_add1 + conv_out;
                
                data_out <= add[19:7] + exp_bias[con_w3];
                waddr    <= con_wl8 + con_wh8 * 8 + con_w3 * 64;
                
                if (wen_fft3 && con_l8 == 1) // Use delayed wen signal (Stage 3)
                    waddr_flag <= 1;
                
                if (waddr_flag == 1) begin
                    if (con_wl8 == 7) begin
                        con_wl8 <= 0;
                        if (con_w3 == 2) begin
                            con_w3     <= 0;
                            con_wh8    <= con_wh8 + 1;
                            waddr_flag <= 0;
                        end
                        else
                            con_w3 <= con_w3 + 1;
                    end
                    else
                        con_wl8 <= con_wl8 + 1;
                end
            end
        end
    end
    
    conv2_cache ramt1(
        .dina    (conv_out),
        .addra  (conv_addr_d), // Use delayed address
        .ena    (wen_fft3 && cnt_3 == 0), // Use delayed wen signal (Stage 3)
        .wea    (wea),
        .doutb    (conv_out_add0),
        .addrb  (conv_raddr),
        .enb    (write_flag),
        .clka   (clk),
        .clkb   (clk)
    );
    
    // RAM modules for intermediate storage
    conv2_cache ramt2(
        .dina    (conv_out),
        .addra  (conv_addr_d), // Use delayed address
        .ena    (wen_fft3 && cnt_3 == 1), // Use delayed wen signal (Stage 3)
        .wea    (wea),
        .doutb    (conv_out_add1),
        .addrb  (conv_raddr),
        .enb    (write_flag),
        .clka   (clk),
        .clkb   (clk)
    );
    
    // Final output RAM
    full_cache_256 RAM1(
        .dina    (data_out),
        .addra  (waddr),
        .ena    (write),
        .wea    (wea),
        .doutb    (ram_dob),
        .addrb  (ram_addrb),
        .enb    (ram_ceb),
        .clka   (clk),
        .clkb   (clk)
    );

endmodule
