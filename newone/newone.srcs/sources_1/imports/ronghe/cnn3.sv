`timescale 1ns / 1ps

// CNN module for processing RGB channels
module cnn3 (
    input  logic                clk_in,
    input  logic                rst_n,
    input  logic [15:0]         data_in,
    input  logic                start,
    output logic [15:0]         data_out,
    output logic                ready
);

    // RGB channel signals
    logic [7:0] G1_VGA_R, G1_VGA_G, G1_VGA_B;
    logic [7:0] data_out1_R, data_out1_G, data_out1_B;
    logic ready_R, ready_G, ready_B;
    
    // Ready when all channels are ready
    assign ready = ready_R && ready_G && ready_B;
    
    // Extract RGB from 16-bit input
    assign G1_VGA_R = {data_in[15:11], data_in[13:11]};
    assign G1_VGA_G = {data_in[10:5], data_in[6:5]};
    assign G1_VGA_B = {data_in[4:0], data_in[2:0]};
    
    // Combine processed RGB to output
    always_ff @(posedge clk_in) begin
        data_out <= {data_out1_R[7:3], data_out1_G[7:2], data_out1_B[7:3]};
    end

    // CNN for Red channel
    cnn_gus #(
        .bits(8),
        .filter_size(9),
        .filter_size_2(4)
    ) cnn_gus_R (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .data_in(G1_VGA_R),
        .start(start),
        .data_out(data_out1_R),
        .ready(ready_R)
    );
    
    // CNN for Green channel
    cnn_gus #(
        .bits(8),
        .filter_size(9),
        .filter_size_2(4)
    ) cnn_gus_G (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .data_in(G1_VGA_G),
        .start(start),
        .data_out(data_out1_G),
        .ready(ready_G)
    );
    
    // CNN for Blue channel
    cnn_gus #(
        .bits(8),
        .filter_size(9),
        .filter_size_2(4)
    ) cnn_gus_B (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .data_in(G1_VGA_B),
        .start(start),
        .data_out(data_out1_B),
        .ready(ready_B)
    );

endmodule
