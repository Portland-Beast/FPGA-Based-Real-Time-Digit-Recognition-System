module vga_sync_gen
#(  parameter H_ACTIVE = 640, 
    parameter H_FRONT  = 16,
    parameter H_SYNC = 96,
    parameter H_BACK   = 48,   
    parameter V_ACTIVE = 480,
    parameter V_FRONT  = 10,   
    parameter V_SYNC   = 2,
    parameter V_BACK   = 33)
    (   input logic     clk_in,
        input logic     rst_n,
        output logic [9:0]   pixel_x,
        output logic [9:0]   pixel_y,
        output logic      video_on,
        output logic      hsync_out,
        output logic     vsync_out
    );
     
     // Horizontal timing constants
     localparam H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK; 
     localparam H_SYNC_START = H_ACTIVE + H_FRONT;
     localparam H_SYNC_END   = H_ACTIVE + H_FRONT + H_SYNC;
             
     // Vertical timing constants
     localparam V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
     localparam V_SYNC_START = V_ACTIVE + V_FRONT;
     localparam V_SYNC_END   = V_ACTIVE + V_FRONT + V_SYNC;
          
          logic [9:0] h_cnt;
     logic [9:0] v_cnt; 
       // Output assignments
     assign pixel_x   = h_cnt;
     assign pixel_y   = v_cnt;
     
     // Video active signal generation
     assign video_on  = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE); 
     // Sync signals
     assign hsync_out = ~((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END));
     assign vsync_out = ~((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END)); 
     

     
     // Horizontal and Vertical Counters
     always_ff @(posedge clk_in or negedge rst_n)
     begin
        if(!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end
        else begin
            if(h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if(v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0; 
                else
                    v_cnt <= v_cnt + 1'b1;
            end 
            else begin
                h_cnt <= h_cnt + 1'b1; 
            end
        end
     end 
        
   
                        
endmodule
