`timescale 1ns/ 1ps

// Module to convert RGB565 to grayscale
module rgb2gray(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] data_in,      // RGB565 input
    input  logic        start,
    output logic [7:0]  data_out,     // Grayscale output
    output logic [9:0]  waddr,        // Write address
    output logic        wen           // Write enable
);

// Internal signals
logic        start_fft1, start_fft2, start_fft3;
logic [10:0] GRAY, R, G, B;

// Counters for address calculation
logic [5:0]  cnt_18, cnt_22;

// Conversion logic
always_ff @(posedge clk or negedge rst_n) begin  
    if (~rst_n) begin
        start_fft1  <= '0; 
        start_fft2  <= '0; 
        start_fft3  <= '0; 
        wen         <= '0;
        R           <= '0;
        G           <= '0; 
        B           <= '0; 
        GRAY        <= '0;           
    end
    else begin 
        start_fft1 <= start;
        start_fft2 <= start_fft1;
        start_fft3 <= start_fft2;
        wen        <= start_fft3;
        
        if (start_fft1 == 1'b1) begin
            R[10:0] <= {2'b00,  data_in[15:11], data_in[13:11], 1'b0};
            G[10:0] <= {3'b000, data_in[10:5],  data_in[6:5]};
            B[10:0] <= {3'b000, data_in[4:0],   data_in[2:0]}; 
        end
        
        if (start_fft2 == 1'b1) begin
            GRAY <= (R + G * 5 + B > 1536) ? (R + G * 5 + B) : 11'd0;
        end
    end 
end 

// Address generation logic
always_ff @(posedge clk or negedge rst_n) begin  
    if (~rst_n) begin 
        data_out <= '0;
        waddr    <= '0; 
        cnt_18   <= '0;
        cnt_22   <= '0;          
    end
    else begin  
        if (start_fft3 == 1'b1) begin
            data_out <= GRAY >> 3; 
            waddr    <= 10'd106 + cnt_22 * 6'd28 - cnt_18;
            cnt_22   <= cnt_22 + 1'b1;
            
            if (cnt_22 == 5'd21) begin
                cnt_22 <= '0;
                cnt_18 <= cnt_18 + 1'b1;
            end
        end
        else begin
            data_out <= '0;
            waddr    <= '0; 
            cnt_18   <= '0; 
            cnt_22   <= '0; 
        end
    end 
end 

endmodule

