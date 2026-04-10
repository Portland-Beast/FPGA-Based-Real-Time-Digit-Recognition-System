`timescale 1ns / 1ps

// Max pooling core module
module pool_core0
    #(
        parameter bits = 8,              // Bit width of data
        parameter filter_size = 4,       // Size of pooling filter
        parameter filter_size_2 = 2      // Log2 of filter size
    )
    (
        // System clock and reset
        input  logic                    clk_in,
        input  logic                    rst_n,
        // Feature map input
        input  logic signed [bits-1:0]  data_in,
        // Enable pooling
        input  logic                    start,
        // Feature map output
        output logic signed [bits-1:0]  data_out,
        // Enable next module
        output logic                    ready
    );

    logic signed [bits-1:0]             pool_result, pool_result_fft1;
    logic signed [bits-1:0]             data_in_reg;  // Pipeline register
    logic                               flag;
    logic [filter_size_2-1:0]           cnt;
    logic [1:0]                         out_flag;
    logic                               out_ready;
    logic                               out_cnt;

    logic bigger, bigger_reg;
    
    // Pipeline stage 1: Register input and comparison
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            data_in_reg <= '0;
            bigger_reg <= '0;
        end
        else begin
            data_in_reg <= data_in;
            bigger_reg <= (pool_result <= data_in) ? 1'b1 : 1'b0;
        end
    end
    
    assign bigger = bigger_reg;

    // Pooling computation logic
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n || (start == 1'b0 && flag == 1'b0)) begin
            cnt             <= '0;
            pool_result     <= '0;
            flag            <= '0;
        end else begin
            if (flag == 1'b1 || start == 1'b1) begin
                if (cnt == 0) begin
                    cnt                 <= cnt + 1'b1;
                    pool_result         <= data_in_reg;
                    pool_result_fft1    <= pool_result;
                    flag                <= 1'b1;
                end else if (cnt < filter_size - 1) begin
                    cnt                 <= cnt + 1'b1;
                    pool_result         <= bigger ? data_in_reg : pool_result;
                    flag                <= 1'b1;
                end else if (cnt == filter_size - 1) begin
                    pool_result         <= bigger ? data_in_reg : pool_result;
                    flag                <= 1'b0;
                    cnt                 <= 1'b0;
                end
            end
        end
    end

    // Output control logic
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n || (start == 1'b0 && flag == 1'b0)) begin
            out_cnt         <= '0;
            out_ready       <= '0;
            ready           <= '0;
            data_out        <= '0;
            out_flag        <= '0;
        end else begin
            out_flag <= {out_flag[0], flag};

            if (out_flag[0] && (~flag)) begin
                out_ready   <= 1'b1;
            end

            if (out_ready) begin
                if (out_cnt == 0) begin
                    ready       <= 1'b1;
                    data_out    <= pool_result_fft1;
                    out_cnt     <= out_cnt + 1'b1;
                end else if (out_cnt == 1'b1) begin
                    out_cnt     <= 1'b0;
                    out_ready   <= 1'b0;
                    ready       <= 1'b0;
                end
            end
        end
    end

endmodule
