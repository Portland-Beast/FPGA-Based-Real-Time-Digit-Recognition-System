`timescale 1ns / 1ps

// Preprocessing layer module
module pre_layer (
    // System clock and reset
    input  logic        clk,
    input  logic        rst_n,
    
    // P2 layer interface
    input  logic [15:0] data_in,
    input  logic        ren_P2,
    output logic [8:0]  addr_P2,
    
    // Y748 RAM interface
    input  logic [9:0]  addrb,
    input  logic        ceb,
    output logic [7:0]  dob,
    output logic        ren_Y748,
    
    // VGA display interface
    input  logic [9:0]  addrb_vga,
    output logic [7:0]  dob_vga
);

    // Internal signals
    logic [7:0] gray;
    logic [9:0] addra;
    logic       start;
    logic [0:0] wea;
    
    assign wea = 1'b1;
    
    // Submodule instantiations
    
    // Read from P2 RAM
    read_ramp2 u_read_ramp2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .ren_P2     (ren_P2),
        .addr_P2    (addr_P2),
        .start      (start)
    );
    
    // Convert RGB to gray
    rgb2gray u_rgb2gray (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (data_in),
        .start      (start),
        .data_out   (gray),
        .waddr      (addra),
        .wen        (ren_Y748)
    );
    
    // RAM for Y784
    pre_1024 y_784 (
        .dina        (gray),
        .addra      (addra),
        .ena        (ren_Y748),
        .clka       (clk),
        .wea        (wea),
        .doutb        (dob),
        .addrb      (addrb),
        .enb        (ceb),
        .clkb       (clk)
    );
    
    // RAM for VGA
    pre_1024 ram_2vga (
        .dina        (gray),
        .addra      (addra),
        .ena        (ren_Y748),
        .clka       (clk),
        .wea        (wea),
        .doutb        (dob_vga),
        .addrb      (addrb_vga),
        .enb        (1'b1),
        .clkb       (clk)
    );

endmodule
