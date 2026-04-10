`timescale 1ns/ 1ps

// Module to read from RAM P2 and generate addresses for preprocessing
module read_ramp2( 
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ren_P2,
    output logic [8:0]  addr_P2,
    output logic        start
);

// Registers for control logic
logic        ren_P2_fft1;
logic [39:0] clk_div;
logic        clk_div39, clk_div39_fft1;
logic        div;
logic        start_raddr;

// Registers for address calculation
logic [8:0]  cnt;
logic [5:0]  cnt_18, cnt_22;

// Control logic for reading addresses
always_ff @(posedge clk or negedge rst_n) begin  
    if (~rst_n) begin
        ren_P2_fft1      <= '0;        
        clk_div          <= '0; 
        clk_div39        <= '0;   
        clk_div39_fft1   <= '0;    
        div              <= '0;   
        start_raddr      <= '0;          
    end
    else begin
        ren_P2_fft1     <= ren_P2;
        clk_div         <= clk_div + 1'b1;
        clk_div39       <= clk_div[27];
        clk_div39_fft1  <= clk_div39;
        
        if (clk_div39_fft1 != clk_div39 && clk_div39_fft1 == 1'b1) begin 
            div <= 1'b1;
        end
        
        if (ren_P2_fft1 != ren_P2 && ren_P2_fft1 == 1'b1 && div == 1'b1) begin 
            start_raddr <= 1'b1; 
            div         <= 1'b0;
        end
        
        if (cnt == 9'd395) begin
            start_raddr <= 1'b0; 
        end
    end
end

// Address generation logic
always_ff @(posedge clk or negedge rst_n) begin  
    if (~rst_n) begin
        cnt      <= '0;        
        cnt_22   <= '0;
        cnt_18   <= '0;     
        addr_P2  <= '0;
        start    <= '0;          
    end
    else begin
        if (addr_P2 == 9'd412) begin
            addr_P2 <= '0;
            start   <= '0;   
        end
        
        if (start_raddr == 1'b1) begin
            start   <= 1'b1; 
            addr_P2 <= cnt_22 + cnt_18 * 5'd23;
            cnt     <= cnt + 1'b1;
            cnt_22  <= cnt_22 + 1'b1;
            
            if (cnt_22 == 5'd21) begin
                cnt_22 <= '0;
                cnt_18 <= cnt_18 + 1'b1;
            end
            
            if (cnt == 9'd395) begin
                cnt_18 <= '0;
                cnt    <= '0;
            end
        end
    end
end

endmodule
