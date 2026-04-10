`timescale 1ns / 1ps

// CNN Read Control Module
module cnn_read (
    input  logic        clk_b,
    input  logic        rstb_n,
    input  logic        clk_div,
    output logic [15:0] ram_raddr,
    output logic [15:0] ram_waddr,
    output logic        ram_wen,
    input  logic        cnn_ready,
    output logic        cnn_start
);

    // Image processing parameters
    localparam int IMAGE_WIDTH = 100;
    localparam int IMAGE_HEIGHT = 80;
    localparam int OUTPUT_WIDTH = 98;
    localparam int OUTPUT_HEIGHT = 78;
    localparam int TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT - 1;
    localparam int OUTPUT_PIXELS = OUTPUT_WIDTH * OUTPUT_HEIGHT - 1;
    localparam int FILTER_SIZE = 9;

    logic        ram_ren;
    logic        ram_ren_ff1;
    logic        ram_ren_ff2; // Added for extra delay
    logic [14:0] cnt_ready;
    logic        clk_div_ff1;
    logic [7:0]  cnt_l;
    logic [7:0]  cnt_h;
    logic [3:0]  cnt;
    logic [1:0]  cnt_n;

    assign cnt_n[0] = (cnt[2:0] == 3'b011 || cnt[2:0] == 3'b100 || cnt[2:0] == 3'b101);
    assign cnt_n[1] = (cnt[2:0] == 3'b110 || cnt[2:0] == 3'b111 || cnt[3] == 1'b1);

    // RAM read enable control
    always_ff @(posedge cnn_ready or negedge rstb_n) begin
        if (!rstb_n) begin
            cnt_ready <= '0;
        end else begin
            if (cnt_ready != OUTPUT_PIXELS)
                cnt_ready <= cnt_ready + 1'b1;
            else if (cnt_ready == OUTPUT_PIXELS)
                cnt_ready <= '0;
        end
    end

    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            ram_ren <= 1'b0;
            ram_ren_ff1 <= 1'b0;
            ram_ren_ff2 <= 1'b0;
            clk_div_ff1 <= 1'b0;
        end else begin
            ram_ren_ff1 <= ram_ren;
            ram_ren_ff2 <= ram_ren_ff1; // Pipeline delay
            clk_div_ff1 <= clk_div;
            if (clk_div_ff1 != clk_div && clk_div_ff1 == 1'b1)
                ram_ren <= 1'b1;
            else if (ram_raddr == TOTAL_PIXELS)
                ram_ren <= 1'b0;
        end
    end

    // RAM read address generation
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n || !ram_ren) begin
            cnt_l <= '0;
            cnt_h <= '0;
            cnt <= '0;
            ram_raddr <= '0;
        end else begin
            if (ram_ren) begin
                ram_raddr <= cnt_l + cnt_h * IMAGE_WIDTH + cnt + cnt_n * (IMAGE_WIDTH - 3);
                if (cnt >= 0 && cnt <= 7)
                    cnt <= cnt + 1'b1;
                else if (cnt == 8)
                    cnt <= '0;
                if (cnt == 8) begin
                    if (cnt_l >= 0 && cnt_l <= 96)
                        cnt_l <= cnt_l + 1'b1;
                    else if (cnt_l == 97)
                        cnt_l <= '0;
                end
                if (cnt == 8 && cnt_l == 97) begin
                    if (cnt_h >= 0 && cnt_h <= 76)
                        cnt_h <= cnt_h + 1'b1;
                    else if (cnt_h == 77)
                        cnt_h <= '0;
                end
            end
        end
    end

    // RAM write control
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            ram_waddr <= '0;
            ram_wen <= 1'b0;
        end else begin
            if (cnn_ready && ram_waddr != (OUTPUT_PIXELS - 1)) begin
                ram_waddr <= cnt_ready - 1'b1;
                ram_wen <= 1'b1;
            end else if (ram_waddr == (OUTPUT_PIXELS - 1) && cnn_ready) begin
                ram_waddr <= OUTPUT_PIXELS;
                ram_wen <= 1'b1;
            end else if (ram_waddr == OUTPUT_PIXELS) begin
                ram_waddr <= '0;
                ram_wen <= 1'b0;
            end
        end
    end

    // CNN start control
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            cnn_start <= 1'b0;
        end else begin
            if (ram_ren_ff2 == 1'b1) // Changed from ff1 to ff2
                cnn_start <= 1'b1;
            if (ram_ren_ff2 == 1'b0) // Changed from ff1 to ff2
                cnn_start <= 1'b0;
        end
    end

endmodule
