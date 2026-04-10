module display_controller
    (   input logic          clk_pixel,
        input logic          rst_n,
        
        // Configuration inputs
        input logic [9:0]    i_disp_width,
        input logic [9:0]    i_disp_height,
        input logic [18:0]   i_addr_max,
        
        // VGA driver signals
        output logic [9:0]   x_pos,
        output logic [9:0]   y_pos, 
        output logic         vsync,
        output logic         hsync, 
        output logic         video_active,
        output logic [4:0]   red_out, 
        output logic [4:0]   blue_out,
        output logic [5:0]   green_out,
      
        output logic         de_out,        // vde signal
        
        // VGA read from BRAM 
        input logic [15:0]   pixel_data_in,
        output reg  [18:0]   pixel_addr_out
    );
 
    reg [4:0]   red_reg, blue_reg; 
    reg [5:0]   green_reg;
    reg [1:0]   state_curr;
    
    localparam [1:0]    IDLE_1  = 0,
                        IDLE_2  = 'd1,  
                        ACTIVE  = 'd2;
                          
    always_ff @(posedge clk_pixel or negedge rst_n)
    if(!rst_n)
    begin
        state_curr <= IDLE_1;
        pixel_addr_out <= 0; 
    end
    else
        case(state_curr)
        // Skip two frames
        IDLE_1: state_curr <= (x_pos == 640 && y_pos == 480) ? IDLE_2 : IDLE_1;
        IDLE_2: state_curr <= (x_pos == 640 && y_pos == 480) ? ACTIVE : IDLE_2; 
        ACTIVE: begin
            if((y_pos < i_disp_height) && (x_pos < i_disp_width - 1)) 
                pixel_addr_out <= (pixel_addr_out >= i_addr_max) ? 0 : pixel_addr_out + 1'b1;
            else begin           
                // Next clock is active video 
                if( (x_pos == 799) && ( (y_pos == 524) || (y_pos < i_disp_height) ) )
                    pixel_addr_out <= (pixel_addr_out >= i_addr_max) ? 0 : pixel_addr_out + 1'b1;
                // Next clock not active video 
                else if(y_pos >= i_disp_height)
                    pixel_addr_out <= 0;
            end
        end 
        endcase
    
    // Valid Video selects between a black RGB Pixel and BRAM pixel data 
    always_comb
        begin
            if(video_active && x_pos < i_disp_width && y_pos < i_disp_height)    
                begin
                    red_reg   = pixel_data_in[15:11];    // rgb565
                    green_reg = pixel_data_in[10:5];
                    blue_reg  = pixel_data_in[4:0];
                end
            else begin
                    red_reg   = 0; 
                    green_reg = 0;
                    blue_reg  = 0;
            end
        end 
    
    
    
    
    
    
    
    assign red_out    = red_reg;
    assign green_out  = green_reg;
    assign blue_out   = blue_reg;
    
    // CRITICAL FIX: active_nblank must be high for the ENTIRE 640x480 frame
    assign de_out = video_active;

   
    vga_sync_gen
    #(  .H_ACTIVE(640), 
        .H_FRONT(16), 
        .H_SYNC(96), 
        .H_BACK(48), 
        .V_ACTIVE(480), 
        .V_FRONT(10), 
        .V_SYNC(2),
        .V_BACK(33)                )
    sync_inst
    (   .clk_in(clk_pixel       ),
        .rst_n(rst_n   ),
        
        // VGA timing signals
        .pixel_x(x_pos          ),
        .pixel_y(y_pos          ),
        .video_on(video_active  ), 
        .vsync_out(vsync        ),
        .hsync_out(hsync        )
    );
    




endmodule
