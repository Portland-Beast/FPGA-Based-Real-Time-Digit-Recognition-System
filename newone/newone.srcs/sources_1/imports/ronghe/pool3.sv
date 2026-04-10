`timescale 1ns / 1ps

module pool3 (
    input  logic                clk,
    input  logic                rst,
    input  logic [15:0]         data_in,
    input  logic                start,
    output logic [15:0]         data_out,
    output logic                ready
);

    // Pooling layer for RGB channels
    logic [7:0] G1_VGA_R, G1_VGA_G, G1_VGA_B;
    logic [7:0] data_out1_R, data_out1_G, data_out1_B;
    logic ready_R, ready_G, ready_B;
    
    assign ready = ready_R && ready_G && ready_B; // All channels ready
    
    // Extract RGB from RGB565 input
    assign G1_VGA_R = {data_in[15:11], data_in[13:11]};
    assign G1_VGA_G = {data_in[10:5], data_in[6:5]};
    assign G1_VGA_B = {data_in[4:0], data_in[2:0]};
    
    // Combine RGB to output
    always_ff @(posedge clk) begin
        data_out <= {data_out1_R[7:3], data_out1_G[7:2], data_out1_B[7:3]};
    end

    // Pooling cores for each channel
    pool_core #(
        .bits(8),
        .filter_size(4),
        .filter_size_2(2)
    ) pool_core_r (
        .clk_in(clk),
        .rst_n(rst),
        .data_in(G1_VGA_R),
        .start(start),
        .data_out(data_out1_R),
        .ready(ready_R)
    );
    
    pool_core #(
        .bits(8),
        .filter_size(4),
        .filter_size_2(2)
    ) pool_core_g (
        .clk_in(clk),
        .rst_n(rst),
        .data_in(G1_VGA_G),
        .start(start),
        .data_out(data_out1_G),
        .ready(ready_G)
    );
    
    pool_core #(
        .bits(8),
        .filter_size(4),
        .filter_size_2(2)
    ) pool_core_b (
        .clk_in(clk),
        .rst_n(rst),
        .data_in(G1_VGA_B),
        .start(start),
        .data_out(data_out1_B),
        .ready(ready_B)
    );

endmodule
