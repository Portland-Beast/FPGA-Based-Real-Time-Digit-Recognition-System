`timescale 1ns / 1ps

module cnn_read_c2 (
    input  logic        clk_b,
    input  logic        rstb_n,
    input  logic        clk_div,
    output logic [15:0] ram_raddr,
    output logic [15:0] ram_waddr,
    output logic        ram_wen,
    input  logic        CNN_ready,
    output logic        CNN_start
);

    logic               ram_ren;
    logic               ram_ren_fft1;
    logic [14:0]        cnt_ready;
    logic               clk_div_fft1;
    
    // 3x3 convolution window
    logic [7:0]         cnt_l;
    logic [7:0]         cnt_h;
    logic [3:0]         cnt;
    logic [1:0]         cnt_n;
    
    assign cnt_n[0] = (cnt[2:0] == 3'b011 || cnt[2:0] == 3'b100 || cnt[2:0] == 3'b101) ? 1'b1 : 1'b0;

    assign cnt_n[1] = (cnt[2:0] == 3'b110 || cnt[2:0] == 3'b111 || cnt[3] == 1'b1) ? 1'b1 : 1'b0;
    
    always_ff @(posedge CNN_ready or negedge rstb_n) begin
        if (!rstb_n) begin
            cnt_ready <= '0;
        end
        else begin
            if (cnt_ready <= 1737)
                cnt_ready <= cnt_ready + 1'b1;
            else if (cnt_ready == 1738)
                cnt_ready <= '0;
        end
    end
    
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            ram_ren <= 1'b0;
            ram_ren_fft1 <= 1'b0;
            clk_div_fft1 <= 1'b0;
        end
        else begin
            ram_ren_fft1 <= ram_ren;
            clk_div_fft1 <= clk_div;
            
            if (clk_div_fft1 != clk_div && clk_div_fft1 == 1'b1)
                ram_ren <= 1'b1;
            else if (ram_raddr == 1910)
                ram_ren <= 1'b0;
        end
    end
    
    // 3x3 sliding window address generation
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n || !ram_ren) begin
            cnt_l <= '0;
            cnt_h <= '0;
            cnt <= '0;
            ram_raddr <= '0;
        end
        else begin
            if (ram_ren) begin
                ram_raddr <= cnt_l + cnt_h * 49 + cnt + cnt_n * 46;
                
                if (cnt >= 0 && cnt <= 7)
                    cnt <= cnt + 1;
                else if (cnt == 8)
                    cnt <= '0;
                
                if (cnt == 8) begin
                    if (cnt_l >= 0 && cnt_l <= 45)
                        cnt_l <= cnt_l + 1;
                    else if (cnt_l == 46)
                        cnt_l <= '0;
                end
                
                if (cnt == 8 && cnt_l == 46) begin
                    if (cnt_h >= 0 && cnt_h <= 35)
                        cnt_h <= cnt_h + 1;
                    else if (cnt_h == 36)
                        cnt_h <= '0;
                end
            end
        end
    end
    
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            ram_waddr <= '0;
            ram_wen <= 1'b0;
        end
        else begin
            if (CNN_ready && ram_waddr != 1738 && ram_raddr != 0) begin
                ram_waddr <= cnt_ready - 1'b1;
                ram_wen <= 1'b1;
            end
            else if (ram_waddr == 1737 && CNN_ready) begin
                ram_waddr <= 16'd1738;
                ram_wen <= 1'b1;
            end
            else if (ram_waddr == 1738) begin
                ram_waddr <= '0;
                ram_wen <= 1'b0;
            end
        end
    end
    
    always_ff @(posedge clk_b or negedge rstb_n) begin
        if (!rstb_n) begin
            CNN_start <= 1'b0;
        end
        else begin
            if (ram_ren_fft1)
                CNN_start <= 1'b1;
            else
                CNN_start <= 1'b0;
        end
    end

endmodule
