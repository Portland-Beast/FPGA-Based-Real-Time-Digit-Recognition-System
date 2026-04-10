module ov7670_capture (
    input  logic        clk,
    input  logic        rst,
    input  logic        config_finished,

    // camera signals  
    input  logic        ov7670_vsync,
    input  logic        ov7670_href,
    input  logic        ov7670_pclk,
    input  logic [7:0]  ov7670_data,
    input  logic        start,
    output logic        frame_finished_o,
    output logic [15:0] pixel_data,

    // frame_buffer signals
    output logic [0:0]  wea,
   // output logic [11:0] dina,
   output logic [15:0] dina,
    output logic [18:0] addra
);

    typedef enum logic [2:0] {
        IDLE,
        START_CAPTURING,
        WAIT_FOR_NEW_FRAME,
        FRAME_FINISHED,
        CAPTURE_BYTE_1,
        CAPTURE_BYTE_2,
        WRITE_TO_BRAM
    } state_t;

    typedef struct packed {
        state_t       state;
        int           href_cnt;
        logic [15:0]  rgb_reg;
        int           pixel_reg;
        logic [18:0]  bram_address;
    } reg_t;

    localparam reg_t INIT_REG_FILE = '{
        state: IDLE,
        href_cnt: 0,
        rgb_reg: '0,
        pixel_reg: 0,
        bram_address: '0
    };

    // registers
    logic vsync_reg, vsync_next;
    logic href_reg, href_next;
    logic pclk_reg, pclk_next;

    logic vsync_falling_edge, vsync_rising_edge;
    logic href_rising_edge, href_falling_edge;
    logic pclk_edge;

    reg_t r, r_next;

    assign addra = r.bram_address;
    assign pixel_data = r.rgb_reg;

    assign vsync_next = ov7670_vsync;
    assign vsync_falling_edge = (vsync_reg == 1'b1 && ov7670_vsync == 1'b0) ? 1'b1 : 1'b0; // detect falling edge of external vsync signal (start of frame) 
    assign vsync_rising_edge  = (vsync_reg == 1'b0 && ov7670_vsync == 1'b1) ? 1'b1 : 1'b0; // detect rising edge of external vsync signal (end of frame) 

    assign href_next = ov7670_href; // register external href signal from camera

    assign href_rising_edge  = (href_reg == 1'b0 && ov7670_href == 1'b1) ? 1'b1 : 1'b0;
    assign href_falling_edge = (href_reg == 1'b1 && ov7670_href == 1'b0) ? 1'b1 : 1'b0;

    assign pclk_next = ov7670_pclk;
    assign pclk_edge = (pclk_reg == 1'b0 && ov7670_pclk == 1'b1) ? 1'b1 : 1'b0; 

    always_ff @(posedge clk) begin
        if (rst) begin 
            r <= INIT_REG_FILE;
            vsync_reg <= 1'b0;
            pclk_reg <= 1'b0;
            href_reg <= 1'b0;
        end else begin
            r <= r_next;
            vsync_reg <= vsync_next;
            href_reg <= href_next;
            pclk_reg <= pclk_next;
        end
    end

    always_comb begin
        r_next = r;
        frame_finished_o = 1'b0; 
        wea = 1'b0;
        dina = '0;
        
        // UPDATE: Global VSYNC synchronization
        // If a new frame starts (VSYNC falling edge), force reset regardless of current state.
        // This prevents the FSM from getting stuck or drifting if pixel counts mismatch.
        if (vsync_falling_edge == 1'b1 && config_finished == 1'b1) begin
            r_next.state = START_CAPTURING;
            r_next.href_cnt = 0;
            r_next.pixel_reg = 0;
            r_next.rgb_reg = '0;
            r_next.bram_address = '0;
        end else begin
            case (r.state)
                IDLE: begin
                    if (config_finished == 1'b1) begin 
                        // Wait for VSYNC to sync up first frame
                        r_next.state = WAIT_FOR_NEW_FRAME;
                    end
                end
    
                WAIT_FOR_NEW_FRAME: begin
                    // Just wait, the global VSYNC check above will handle the transition
                end
    
                START_CAPTURING: begin
                    if (href_rising_edge == 1'b1) begin
                        r_next.pixel_reg = 0; // new line: start with pixel position 0
                        r_next.state = CAPTURE_BYTE_1;
                    end
                end

            CAPTURE_BYTE_1: begin
                if (href_falling_edge == 1'b1) begin
                    // End of line detected by HREF, not pixel count
                    r_next.href_cnt = r.href_cnt + 1;
                    if (r.href_cnt == 79) begin
                        r_next.state = FRAME_FINISHED;
                    end else begin
                        r_next.state = START_CAPTURING;
                    end
                end else if (pclk_edge == 1'b1 && ov7670_href == 1'b1) begin
                    r_next.rgb_reg[15:8] = ov7670_data; // capture first byte of pixel data
                    r_next.state = CAPTURE_BYTE_2;
                end
            end

            CAPTURE_BYTE_2: begin
                if (pclk_edge == 1'b1 && ov7670_href == 1'b1) begin
                    r_next.rgb_reg[7:0] = ov7670_data; // capture second byte of pixel data
                    r_next.pixel_reg = r.pixel_reg + 1; // keep track of current pixel position in line
                    r_next.state = WRITE_TO_BRAM;
                end
            end

            WRITE_TO_BRAM: begin
                // Only write if we are within the 100x80 window
                if (r.pixel_reg <= 100 && r.href_cnt < 80) begin
                    wea = 1'b1; // write enable bram
                    // UPDATE: Convert RGB565 to RGB444
                    // RGB565: R[15:11], G[10:5], B[4:0]
                    // RGB444: R[11:8],  G[7:4],  B[3:0]
                    //dina = {r.rgb_reg[15:12], r.rgb_reg[10:7], r.rgb_reg[4:1]};
                    //output rgb 565
                    dina = r.rgb_reg;                    
                    
                    r_next.bram_address = r.bram_address + 1; // increment address register for next pixel
                end
                r_next.state = CAPTURE_BYTE_1; // capture next pixel
            end

            FRAME_FINISHED: begin
                frame_finished_o = 1'b1;
                r_next.rgb_reg = '0;
                r_next.bram_address = '0;
                r_next.state = WAIT_FOR_NEW_FRAME;
            end

            default: ;
        endcase
        end // End of else block for VSYNC check
    end

endmodule
