`timescale 1ns / 1ps

// Pooling read module for 2x2 pooling operation
module pool_read_p1 (
    // Clock and reset signals
    input  logic        clk_b,
    input  logic        rstb_n,
    input  logic        clk_div,

    // RAM read interface
    output logic [15:0] ram_raddr,

    // RAM write interface
    output logic [10:0] ram_waddr,
    output logic        ram_wen,

    // Pooling core interface
    input  logic        POOL_ready,
    output logic        POOL_start
);

    // Internal signals
    logic               ram_ren;
    logic               ram_ren_fft1;
    logic               ram_ren_fft2; // Added for extra delay
    logic [11:0]        cnt_ready;
    logic               clk_div_fft1;
    
    logic               POOL_ready_d;
    wire                POOL_ready_posedge;
    wire                frame_start;

    // Counters for 2x2 pooling
    logic [7:0]         cnt_l;
    logic [7:0]         cnt_h;
    logic [1:0]         cnt;
    logic               cnt_n;

    assign cnt_n = cnt[1];
    
    always_ff @(posedge clk_b) POOL_ready_d <= POOL_ready;
    assign POOL_ready_posedge = POOL_ready && !POOL_ready_d;
    assign frame_start = (ram_ren == 1'b0) && (clk_div_fft1 != clk_div && clk_div_fft1 == 1);

    // Counter for ready signals
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (rstb_n == 1'b0) begin
            cnt_ready <= '0;
        end
        else begin
            if (frame_start)
                cnt_ready <= '0;
            else if (POOL_ready_posedge) begin
                if (cnt_ready != 1910 && ram_raddr != 0)
                    cnt_ready <= cnt_ready + 1'b1;
                else if (cnt_ready == 1910)
                    cnt_ready <= '0;
            end
        end
    end

    // RAM read enable control
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (rstb_n == 1'b0) begin
            ram_ren         <= 1'b0;
            ram_ren_fft1    <= 1'b0;
            ram_ren_fft2    <= 1'b0;
            clk_div_fft1    <= 1'b0;
        end
        else begin
            ram_ren_fft1    <= ram_ren;
            ram_ren_fft2    <= ram_ren_fft1; // Pipeline delay
            clk_div_fft1    <= clk_div;

            if (clk_div_fft1 != clk_div && clk_div_fft1 == 1)
                ram_ren <= 1'b1;
            else if (ram_raddr == 7643)
                ram_ren <= 1'b0;
        end
    end

    // Read address generation
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (rstb_n == 1'b0 || ram_ren == 1'b0) begin
            cnt_l       <= '0;
            cnt_h       <= '0;
            cnt         <= '0;
            ram_raddr   <= '0;
        end
        else begin
            if (ram_ren == 1'd1) begin
                ram_raddr <= cnt_l + cnt_h * 98 + cnt + cnt_n * 96;

                if (cnt >= 0 && cnt <= 2)
                    cnt <= cnt + 1;
                else if (cnt == 3)
                    cnt <= '0;

                if (cnt == 3) begin
                    if (cnt_l >= 0 && cnt_l <= 94)
                        cnt_l <= cnt_l + 2;
                    else if (cnt_l == 96)
                        cnt_l <= '0;
                end

                if (cnt == 3 && cnt_l == 96) begin
                    if (cnt_h >= 0 && cnt_h <= 74)
                        cnt_h <= cnt_h + 2;
                    else if (cnt_h == 76)
                        cnt_h <= '0;
                end
            end
        end
    end

    // Write address and enable control
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (rstb_n == 1'b0) begin
            ram_waddr   <= '0;
            ram_wen     <= 1'b0;
        end
        else begin
            if (frame_start) begin
                ram_waddr <= '0;
                ram_wen <= 1'b0;
            end
            else if (POOL_ready == 1 && ram_waddr != 1909 && ram_raddr != 0) begin
                ram_waddr   <= cnt_ready;
                ram_wen     <= 1'b1;
            end
            else if (ram_waddr == 1909 && POOL_ready == 1) begin
                ram_waddr   <= 1910;
                ram_wen     <= 1'b1;
            end
            else if (ram_waddr == 1910) begin
                ram_waddr   <= '0;
                ram_wen     <= 1'b0;
            end
        end
    end

    // Pooling start signal control
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (rstb_n == 1'b0) begin
            POOL_start <= 1'b0;
        end
        else begin
            if (ram_ren_fft2 == 1'b1) // Changed from fft1 to fft2
                POOL_start <= 1'b1;
            if (ram_ren_fft2 == 1'b0) // Changed from fft1 to fft2
                POOL_start <= 1'b0;
        end
    end

endmodule

