`timescale 1ns / 1ps

// Convolution layer 1 with pooling layer 1
module conv1_layer1 (
    input  logic                clk,
    input  logic                rst_n,
    
    input  logic                ren_Y748,
    input  logic [7:0]          data_in,
    output logic [9:0]          raddr,
    output logic                Y_ren,
    output logic                layer_ren,
    
    input  logic                ram_ceb,
    input  logic [8:0]          ram_addrb,
    output logic signed [11:0]  ram_dob,
    
    output logic                reset_n
);
    logic [0:0] wea;
    logic                       conv1_ren;
    logic                       start, ready;
    logic                       pool1_ram_wen;
    logic [10:0]                pool1_ram_raddr;
    logic [8:0]                 pool1_ram_waddr;
    logic signed [11:0]         pool1_data_in;
    logic signed [11:0]         pool1_data_out;
    logic signed [11:0]         pool1_data_out_fft1;
    
    logic [1:0]                 cnt_3;
    logic [2:0]                 cnt_8;
    logic                       pool1_layer_start;
    logic                       conv1_ren_fft1;
    logic                       pool1_ram_wen_fft1;
    logic                       flag_wait;
    
    
    // Submodule instantiations
    
    conv1 u_conv1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .ren_Y748   (ren_Y748),
        .data_in    (data_in),
        .raddr      (raddr),
        .Y_ren      (Y_ren),
        .conv1_ren  (conv1_ren),
        .ram_addrb  (pool1_ram_raddr + cnt_3 * 576),
        .ram_dob    (pool1_data_in),
        .ram_ceb    (1'b1)
    );
    
    pool1_layer #(
        .DATA_BIT       (12),
        .RADDR_BIT      (11),
        .WADDR_BIT      (9),
        .HALF_WIDTH     (12),
        .HALF_HEIGHT    (12)
    ) u_pool1_layer (
        .clk            (clk),
        .rst_n          (rst_n),
        .clk_div        (pool1_layer_start),
        .ram_raddr      (pool1_ram_raddr),
        .ram_waddr      (pool1_ram_waddr),
        .ram_wen        (pool1_ram_wen),
        .POOL_ready     (ready),
        .POOL_start     (start)
    );
    
    pool_core0 #(
        .bits           (12),
        .filter_size    (4),
        .filter_size_2  (2)
    ) POOL_CORE_R (
        .clk_in     (clk),
        .rst_n      (rst_n),
        .data_in    (pool1_data_in),
        .start      (start),
        .data_out   (pool1_data_out),
        .ready      (ready)
    );
    
    full_cache_512 cache1 (
        .dina        (pool1_data_out_fft1),
        .addra      (pool1_ram_waddr + 144 * cnt_3),
        .ena        (pool1_ram_wen),
        .clka       (clk),
        .wea        (wea),
        .doutb        (ram_dob),
        .addrb      (ram_addrb),
        .enb        (ram_ceb),
        .clkb       (clk)
    );
    
    // Control logic
    
    always_ff @(posedge clk) begin
        pool1_data_out_fft1 <= pool1_data_out;
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0)
            layer_ren <= 1'b1;
        else begin
            if (pool1_ram_waddr + 144 * cnt_3 == 431)
                layer_ren <= 1'b0;
            else
                layer_ren <= 1'b1;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            cnt_3               <= 2'b00;
            pool1_layer_start   <= 1'b0;
            conv1_ren_fft1      <= 1'b0;
            pool1_ram_wen_fft1  <= 1'b0;
            cnt_8               <= 3'b000;
            flag_wait           <= 1'b0;
        end
        else begin
            conv1_ren_fft1      <= conv1_ren;
            pool1_ram_wen_fft1  <= pool1_ram_wen;
            
            if (pool1_ram_wen_fft1 != pool1_ram_wen && pool1_ram_wen_fft1 == 1 && cnt_3 == 2'b10) begin
                cnt_3 <= 2'b00;
            end
            
            begin
                if (conv1_ren_fft1 != conv1_ren && conv1_ren_fft1 == 1) begin
                    pool1_layer_start <= 1'b0;
                end
                else if (pool1_ram_wen_fft1 != pool1_ram_wen && pool1_ram_wen_fft1 == 1 && cnt_3 != 2'b10) begin
                    flag_wait <= 1'b1;
                end
                else
                    pool1_layer_start <= 1'b1;
            end
            
            if (flag_wait == 1'b1) begin
                if (cnt_8 != 7)
                    cnt_8 <= cnt_8 + 1;
                else begin
                    pool1_layer_start   <= 1'b0;
                    cnt_3               <= cnt_3 + 2'b01;
                    cnt_8               <= '0;
                    flag_wait           <= 1'b0;
                end
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            reset_n <= 1'b1;
        end
        else if (layer_ren == 1'b0)
            reset_n <= 1'b0;
    end

endmodule
