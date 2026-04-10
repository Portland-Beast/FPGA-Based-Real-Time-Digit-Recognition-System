`timescale 1ns/ 1ps

module pool1_layer #(
    parameter int DATA_BIT = 12,
    parameter int RADDR_BIT = 11,
    parameter int WADDR_BIT = 9,
    parameter int HALF_WIDTH = 12,   // Half width of original image
    parameter int HALF_HEIGHT = 12
)(
    input  logic clk,
    input  logic rst_n,
    input  logic clk_div,
    output logic [RADDR_BIT-1:0] ram_raddr,
    output logic [WADDR_BIT-1:0] ram_waddr,
    output logic ram_wen,

    input  logic POOL_ready,
    output logic POOL_start
);

    // Second version, modified ram_ren relationship
    logic ram_ren = 1'b0;          // Read enable signal
    logic ram_ren_fft1 = 1'b0;     // Delayed ram_ren
    logic [RADDR_BIT-1:0] cnt_ready;  // Counter for ready signals
    logic clk_div_fft1;            // Delayed clk_div

    // Using 2x2 pooling
    logic [7:0] cnt_l; // Column counter
    logic [7:0] cnt_h; // Row counter
    logic [1:0] cnt;   // Internal counter 0-3
    logic cnt_n;       // Derived from cnt

    assign cnt_n = cnt[1];

    // ram_ren control
    always_ff @(posedge POOL_ready or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            cnt_ready <= '0;
        end
        else begin
            if (cnt_ready != HALF_WIDTH * HALF_HEIGHT - 1 && ram_raddr != 0)
                cnt_ready <= cnt_ready + 1'b1;
            else if (cnt_ready == HALF_WIDTH * HALF_HEIGHT - 1)
                cnt_ready <= '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            ram_ren <= 1'b0;
            ram_ren_fft1 <= 1'b0;
            clk_div_fft1 <= 1'b0;
        end
        else begin
            ram_ren_fft1 <= ram_ren;
            clk_div_fft1 <= clk_div;
            if (clk_div_fft1 != clk_div && clk_div_fft1 == 1'b1)
                ram_ren <= 1'b1;
            else if (ram_raddr == 4 * HALF_WIDTH * HALF_HEIGHT - 1)
                ram_ren <= 1'b0;
        end
    end

    // Read address calculation
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0 || ram_ren == 1'b0) begin
            cnt_l <= '0;
            cnt_h <= '0;
            cnt <= '0;
            ram_raddr <= '0;
        end
        else begin
            if (ram_ren == 1'd1) begin
                ram_raddr <= cnt_l + cnt_h * 2 * HALF_WIDTH + cnt + cnt_n * (2 * HALF_WIDTH - 2);
                if (cnt >= 0 && cnt <= 2)
                    cnt <= cnt + 1;
                else if (cnt == 3)
                    cnt <= '0;
                if (cnt == 3) begin
                    if (cnt_l >= 0 && cnt_l <= (2 * HALF_WIDTH - 4))
                        cnt_l <= cnt_l + 2;
                    else if (cnt_l == (2 * HALF_WIDTH - 2))
                        cnt_l <= '0;
                end
                if (cnt == 3 && cnt_l == (2 * HALF_WIDTH - 2)) begin
                    if (cnt_h >= 0 && cnt_h <= (2 * HALF_HEIGHT - 4))
                        cnt_h <= cnt_h + 2;
                    else if (cnt_h == (2 * HALF_HEIGHT - 2))
                        cnt_h <= '0;
                end
            end
        end
    end

    // Write address and enable control
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            ram_waddr <= '0;
            ram_wen <= 1'b0;
        end
        else begin
            if (POOL_ready == 1'b1 && ram_waddr != HALF_WIDTH * HALF_HEIGHT - 2 && ram_raddr != 0) begin
                ram_waddr <= cnt_ready - 1'b1;
                ram_wen <= 1'b1;
            end
            else if (ram_waddr == HALF_WIDTH * HALF_HEIGHT - 2 && POOL_ready == 1'b1) begin
                ram_waddr <= HALF_WIDTH * HALF_HEIGHT - 1;
                ram_wen <= 1'b1;
            end
            else if (ram_waddr == HALF_WIDTH * HALF_HEIGHT - 1) begin
                ram_waddr <= '0;
                ram_wen <= 1'b0;
            end
        end
    end

    // POOL_start control
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            POOL_start <= 1'b0;
        end
        else begin
            if (ram_ren_fft1 == 1'b1)
                POOL_start <= 1'b1;
            if (ram_ren_fft1 == 1'b0)
                POOL_start <= 1'b0;
        end
    end

endmodule
