`timescale 1ns / 1ps

module cnn_gus #(
    parameter bits = 8,
    parameter filter_size = 9,
    parameter filter_size_2 = 4
) (
    // Clock and reset
    input  logic                        clk_in,
    input  logic                        rst_n,
    // Feature map input
    input  logic [bits-1:0]             data_in,
    // Control signal
    input  logic                        start,
    // Feature map output
    output logic [bits-1:0]             data_out,
    // Ready signal
    output logic                        ready
);

    // Internal signals
    logic [(bits<<1)-1+filter_size_2:0]  add_result;
    logic [bits-1:0]                      a;
    logic [bits-1:0]                      b;
    logic [(bits<<1)-1:0]                 p;
    logic [(bits<<1)-1:0]                 p_reg;  // Pipeline register for multiplication

    assign a = data_in;

    logic                                        flag;
    logic [filter_size_2-1:0]                    cnt;
    logic [filter_size_2-1:0]                    cnt_reg;  // Pipeline counter
    logic [1:0]                                  out_flag;
    logic                                        out_ready;
    logic [(bits<<1)-1+filter_size_2:0]          temp_out;
    logic                                        out_cnt;

    // Combinational logic for b lookup table
    always_comb begin
        case (cnt)
            0: b = 1;
            1: b = 2;
            2: b = 1;
            3: b = 2;
            4: b = 4;
            5: b = 2;
            6: b = 1;
            7: b = 2;
            8: b = 1;
            
//            0: b = 0;
//            1: b = -1;
//            2: b = 0;
//            3: b = -1;
//            4: b = 4;
//            5: b = -1;
//            6: b = 0;
//            7: b = -1;
//            8: b = 0;
            
            default: b = 0;
        endcase
        p = a * b;
    end
    
    // Pipeline stage 1: Multiplication (registered)
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (~rst_n) begin
            p_reg <= '0;
            cnt_reg <= '0;
        end
        else begin
            p_reg <= p;
            cnt_reg <= cnt;
        end
    end

    // Pipeline stage 2: Accumulation (use registered multiplication result)
    logic flag_reg;
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) flag_reg <= 0;
        else flag_reg <= flag;
    end

    // Input Counter Logic
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (~rst_n || start == 1'b0) begin
            cnt         <= '0;
            flag        <= 1'b0;
        end
        else begin
            if (cnt < filter_size) begin
                if (cnt == filter_size - 1) begin
                    flag <= 1'b0;
                    cnt <= '0;
                end else begin
                    cnt <= cnt + 1'b1;
                    flag <= 1'b1;
                end
            end
        end
    end

    // Accumulation Logic
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (~rst_n) begin
            add_result  <= '0;
            temp_out    <= '0;
        end
        else begin
            if (flag || flag_reg) begin
                if (cnt_reg == 0) begin
                    add_result  <= p_reg;
                end
                else if (cnt_reg < filter_size) begin
                    add_result  <= add_result + p_reg;
                    if (cnt_reg == filter_size - 1) begin
                        temp_out    <= add_result + p_reg;
                    end
                end
            end
        end
    end

    // Output control logic
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (~rst_n) begin
            out_cnt     <= 1'b0;
            out_ready   <= 1'b0;
            ready       <= 1'b0;
            data_out    <= '0;
            out_flag    <= '0;
        end
        else begin
            out_flag <= {out_flag[0], flag};

            if (out_flag[0] && (~flag)) begin
                out_ready   <= 1'b1;
            end

            if (out_ready) begin
                if (out_cnt == 0) begin
                    ready       <= 1'b1;
                    data_out    <= temp_out >> 4;
                    out_cnt     <= out_cnt + 1'b1;
                end
                else if (out_cnt == 1'b1) begin
                    out_cnt     <= 1'b0;
                    out_ready   <= 1'b0;
                    ready       <= 1'b0;
                end
            end
        end
    end

endmodule
