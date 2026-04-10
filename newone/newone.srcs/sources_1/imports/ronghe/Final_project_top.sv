module camera_madness_star
    (   input logic i_top_clk,
        input logic i_top_rst,
        
        input logic  i_top_cam_start, 
        output logic o_top_cam_done, 
        
        // I/O to camera
        input logic       i_top_pclk, 
        input logic [7:0] i_top_pix_byte,
        input logic       i_top_pix_vsync,
        input logic       i_top_pix_href,
        output logic      o_top_reset,
        output logic      o_top_pwdn,
        output logic      o_top_24clk,
        inout  wire       o_top_siod,
        inout  wire       o_top_sioc,
        
    
        // UPDATE: I/O to HDMI
        output logic hdmi_tmds_clk_n,
        output logic hdmi_tmds_clk_p,
        output logic [2:0]hdmi_tmds_data_n,
        output logic [2:0]hdmi_tmds_data_p

    );
    // I/O to VGA 
  //  logic [2:0] o_top_vga_red, o_top_vga_green, o_top_vga_blue;
  logic [4:0] o_top_vga_red, o_top_vga_blue;
  logic [5:0] o_top_vga_green;
    logic       o_top_vga_vsync, o_top_vga_hsync, vde;
    logic o_top_xclk;
    
    
    // Connect cam_top/vga_top modules to BRAM
 //   logic [11:0] i_bram_pix_data,    o_bram_pix_data;
 logic [15:0] i_bram_pix_data, o_bram_pix_data;
    logic [8:0] i_bram_pix_data_nine,    o_bram_pix_data_nine;
    logic [18:0] i_bram_pix_addr,    o_bram_pix_addr; 
    logic        i_bram_pix_wr;
    logic [0:0]  wea; // Signal from capture to memory
           
    // Reset synchronizers for all clock domains
    reg r1_rstn_top_clk,    r2_rstn_top_clk;
    reg r1_rstn_pclk,       r2_rstn_pclk;
    reg r1_rstn_clk25m,     r2_rstn_clk25m;
        
    logic CLK_25MHZ;  //  25MHZ Clock
    logic CLK_125MHZ; // 125MHZ Clock
    logic CLK_24MHZ;  //  24MHZ Clock
    
    
    logic locked; // UPDATE: new
    
  //  assign i_bram_pix_data_nine = {i_bram_pix_data[11:9], i_bram_pix_data[7:5], i_bram_pix_data[3:1]}; // UPDATE: new
    
    
    //clock wizard: 25MHZ and 125MHZ -- removed reset
    clk_wiz_0 clk_wiz_0 (
        .clk_out1(CLK_25MHZ),
        .clk_out2(CLK_125MHZ),
        .clk_out3(CLK_24MHZ), //clock to be passed to camera, not a true 24MHz
        .locked(locked),
        .clk_in1(i_top_clk)
    );
    
    assign o_top_24clk = CLK_24MHZ; // Supply Camera with 25MHz Clock
    assign o_top_cam_done = config_finished; // UPDATE: Assign done signal
    assign o_top_pwdn = 1'b0; // UPDATE: Power up camera
    
    logic w_rst_btn_db; 
    logic w_cam_start_db; // UPDATE: Debounced start signal
    wire config_finished;
    logic frame_finished;
    // Debounce top level button - invert reset to have debounced negedge reset 
    logic i_top_rst_db;
    logic [15:0] pixel_data;
    wire[19:0] buffer1_addra;
    wire[11:0] buffer1_dina;
    sync_debounce button_sync (
           .clk    (i_top_clk),
           
           .d      (~i_top_rst),  // Pass Inverse of Active High
           .q      (w_rst_btn_db) // Active Low
        );
        
    // UPDATE: Debounce start button
    sync_debounce start_sync (
           .clk    (i_top_clk),
           .d      (i_top_cam_start), 
           .q      (w_cam_start_db) 
        );
    
    // Double FF for negedge reset synchronization - Resets are Active Low
    always_ff @(posedge i_top_clk or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_top_clk, r1_rstn_top_clk} <= 0; 
            else              {r2_rstn_top_clk, r1_rstn_top_clk} <= {r1_rstn_top_clk, 1'b1}; 
        end 
    always_ff @(posedge CLK_25MHZ or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_clk25m, r1_rstn_clk25m} <= 0; 
            else              {r2_rstn_clk25m, r1_rstn_clk25m} <= {r1_rstn_clk25m, 1'b1}; 
        end
    always_ff @(posedge i_top_pclk or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_pclk, r1_rstn_pclk} <= 0; 
            else              {r2_rstn_pclk, r1_rstn_pclk} <= {r1_rstn_pclk, 1'b1}; 
        end 
    
    ov7670_configuration ov7670_configuration_inst (
        .clk(i_top_clk),
        .rst(~r2_rstn_top_clk),
        .start(w_cam_start_db), // UPDATE: Connect debounced start signal
        .sda(o_top_siod),
        .scl(o_top_sioc),
        .ov7670_reset(o_top_reset),
        .ack_err(),
        .config_finished(config_finished)
    );
    
        // Camera signal synchronization
    logic [1:0] vsync_sync, href_sync, pclk_sync;
    logic [7:0] data_sync_1, data_sync_2;
    
    always_ff @(posedge i_top_clk) begin
        vsync_sync <= {vsync_sync[0], i_top_pix_vsync};
        href_sync  <= {href_sync[0], i_top_pix_href};
        pclk_sync  <= {pclk_sync[0], i_top_pclk};
        data_sync_1 <= i_top_pix_byte;
        data_sync_2 <= data_sync_1;
    end

    ov7670_capture ov7670_capture_inst (
        .clk(i_top_clk),
        .rst(~r2_rstn_top_clk),
        .start(w_cam_start_db), // UPDATE: Connect debounced start signal
        .config_finished(config_finished),
        .ov7670_vsync(vsync_sync[1]),
        .ov7670_href(href_sync[1]),
        .ov7670_pclk(pclk_sync[1]),
        .ov7670_data(data_sync_2),
        .frame_finished_o(frame_finished),
        .pixel_data(pixel_data),
        .wea(wea),
        .dina(i_bram_pix_data),
        .addra(i_bram_pix_addr)
    );
    
    pixel_memory pixel_memory (
        // BRAM Write signals (cam_top)
        .addra		(i_bram_pix_addr), 
        .clka		(i_top_clk),  //i_top_pclk
        .dina   	(i_bram_pix_data), //i_bram_pix_data_nine
        .ena		(1'b1), 
        .wea		(wea),
        
        // BRAM Read signals (vga_top)
        .addrb		({3'b0, ram_raddr_C1}),     //o_bram_pix_addr
        .clkb		(CLK_25MHZ), 
        .doutb   	(o_bram_pix_data), //o_bram_pix_data_nine
        .enb		(1'b1)
    );
    
    assign data_in1_C1 = o_bram_pix_data;
    
    // Convolution layer C1 signals
logic            ram_wen_C1;
logic [15:0]     data_in1_C1;
logic [15:0]     data_out1_C1;
logic [15:0]     ram_waddr_C1;
logic [15:0]     ram_raddr_C1;
logic [15:0]     data_out_C1;
logic [15:0]     addr_CV_C1;

logic ready_C1;
logic start_C1;


// Pooling layer P1 signals
logic            ready_P1;
logic            start_P1;
logic            ram_wen_P1;
logic [15:0]     data_out1_P1;
logic [15:0]     data_out_P1;
logic [15:0]     addr_CV_P1;
logic [15:0]     ram_raddr_P1;
logic [10:0]     ram_waddr_P1;



//    logic [31:0] divider;
//    logic clk_div;
//    always_ff @(posedge CLK_25MHZ) divider <= divider + 1;
//    assign clk_div = divider[20];



logic clk_div;
logic frame_finished_sync; 
logic frame_finished_prev;

always_ff @(posedge CLK_25MHZ or negedge r2_rstn_clk25m) begin
    if (!r2_rstn_clk25m) begin
        frame_finished_sync <= 1'b0;
        frame_finished_prev <= 1'b0;
    end else begin
        frame_finished_sync <= frame_finished; 
        frame_finished_prev <= frame_finished_sync;
    end
end

assign clk_div = frame_finished_sync && !frame_finished_prev;






// CNN Layer C1: read controller
cnn_read cnn_read_c1
(
    .clk_b      (CLK_25MHZ),
    .rstb_n     (r2_rstn_clk25m),
    .clk_div    (clk_div),
    .cnn_ready  (ready_C1),
    .cnn_start  (start_C1),
    .ram_raddr  (ram_raddr_C1),
    .ram_waddr  (ram_waddr_C1),
    .ram_wen    (ram_wen_C1)
);

// CNN Layer C1: 3x3 convolution unit
cnn3 cnn3_c1
(
    .clk_in     (CLK_25MHZ),
    .rst_n      (r2_rstn_clk25m),
    .data_in    (data_in1_C1),
    .start      (start_C1),
    .data_out   (data_out1_C1),
    .ready      (ready_C1)
);

// CNN Layer C1: result buffer
img_cache cnn_ram_c1
(
    .dina        (data_out1_C1),
    .addra      (ram_waddr_C1),
    .ena        (ram_wen_C1),
    .clka       (CLK_25MHZ),
    .wea        (1'b1),
    .doutb        (data_out_C1),
    .addrb      (addr_CV_C1),    ///addr_CV_C1
    .enb        (1'b1),
    .clkb       (CLK_25MHZ)
);

// Address multiplexing for C1 RAM
assign addr_CV_C1 = (layer_select == 3'b001) ? vga_rdaddr_C1 : ram_raddr_P1;

 // Pooling Layer P1: read controller
pool_read_p1 pool_read_p1_1
(
    .clk_b      (CLK_25MHZ),
    .rstb_n     (r2_rstn_clk25m),
    .clk_div    (ram_wen_C1),
    .POOL_ready (ready_P1),
    .POOL_start (start_P1),
    .ram_raddr  (ram_raddr_P1),
    .ram_waddr  (ram_waddr_P1),
    .ram_wen    (ram_wen_P1)
);

// Pooling Layer P1: 3x3 pooling unit
pool3 p1
(
    .clk        (CLK_25MHZ),
    .rst        (r2_rstn_clk25m),
    .data_in    (data_out_C1),
    .start      (start_P1),
    .data_out   (data_out1_P1),
    .ready      (ready_P1)
);

// Pooling Layer P1: result buffer
mid_cache mid_cache_p1
(
    .dina        (data_out1_P1),
    .addra      (ram_waddr_P1),
    .ena        (ram_wen_P1),
    .clka       (CLK_25MHZ),
    .wea        (1'b1),
    .doutb        (data_out_P1),
    .addrb      (addr_CV_P1),    //o_bram_pix_addr[15:0]
    .enb        (1'b1),
    .clkb       (CLK_25MHZ)
);

// Address multiplexing for P1 RAM
assign addr_CV_P1 = (layer_select == 3'b010) ? vga_rdaddr_P1 : ram_raddr_C2;

   
    // Layer C2 signals
    logic            ready_C2;
    logic            start_C2;
    logic            ram_wen_C2;
    logic [15:0]     data_out1_C2;
    logic [15:0]     data_out_C2;
    logic [15:0]     addr_CV_C2;
    logic [15:0]     ram_raddr_C2;
    logic [10:0]     ram_waddr_C2;
    logic [15:0]     addr_CV_C2_comb;
    
    
      // CNN Layer C2
    cnn_read_c2 cnn_read_c2_1
    (
        .clk_b      (CLK_25MHZ),
        .rstb_n     (r2_rstn_clk25m),
        .clk_div    (ram_wen_P1),
        .CNN_ready  (ready_C2),
        .CNN_start  (start_C2),
        .ram_raddr  (ram_raddr_C2),
        .ram_waddr  (ram_waddr_C2),
        .ram_wen    (ram_wen_C2)
    );
    
    cnn3 cnn3_c2
    (
        .clk_in     (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m),
        .data_in    (data_out_P1),
        .start      (start_C2),
        .data_out   (data_out1_C2),
        .ready      (ready_C2)
    );
    
    mid_cache mid_cache_C2
    (
        .dina        (data_out1_C2),
        .addra      (ram_waddr_C2),
        .ena        (ram_wen_C2),
        .clka       (CLK_25MHZ),
        .wea        (1'b1),
        .doutb        (data_out_C2),
        .addrb      (addr_CV_C2),    //addr_CV_C2
        .enb        (1'b1),
        .clkb       (CLK_25MHZ)
    );
    
    // Address multiplexing for C2 RAM
    assign addr_CV_C2 = (layer_select == 3'b011) ? vga_rdaddr_C2 : ram_raddr_P2;
        
    
    
      // Layer P2 signals
    logic            ready_P2;
    logic            start_P2;
    logic            ram_wen_P2;
    logic [15:0]     data_out1_P2;
    logic [15:0]     data_out_P2;
    logic [15:0]     addr_CV_P2;
    logic [15:0]     ram_raddr_P2;
    logic [10:0]     ram_waddr_P2;
    
    
     // Pooling Layer P2
    pool_read_p2 pool_read_p2_1
    (
        .clk_b      (CLK_25MHZ),
        .rstb_n     (r2_rstn_clk25m),
        .clk_div    (ram_wen_C2),
        .POOL_ready (ready_P2),
        .POOL_start (start_P2),
        .ram_raddr  (ram_raddr_P2),
        .ram_waddr  (ram_waddr_P2),
        .ram_wen    (ram_wen_P2)
    );
    
    pool3 p2
    (
        .clk        (CLK_25MHZ),
        .rst        (r2_rstn_clk25m),
        .data_in    (data_out_C2),
        .start      (start_P2),
        .data_out   (data_out1_P2),
        .ready      (ready_P2)
    );
    
    end_cache end_cache_1
    (
        .dina        (data_out1_P2),
        .addra      (ram_waddr_P2),
        .ena        (ram_wen_P2),
        .clka       (CLK_25MHZ),
        .wea        (1'b1),
        .doutb        (data_out_P2),
        .addrb      (pre_addrb),
        .enb        (1'b1),
        .clkb       (CLK_25MHZ)
    );
    
    // Fully connected layer signals
    logic            Y_ren;
    logic            ren_Y748;
    logic [7:0]      pre_dob;
    logic [9:0]      pre_ram_raddr;
    logic [7:0]      data_out_pre;

    logic            reset_n_conv1;
    logic            layer_ren;
    logic [11:0]     data_in1_conv2_layer;
    logic [10:0]     ram_raddr_conv2_layer;
    logic            Y_ren_conv2_layer;

    logic            reset_n_conv2;
    logic            layer_ren_conv2_layer;
    logic [11:0]     in_full_layer;
    logic [6:0]      raddr_full_layer;
    logic            Y_ren_full_layer;

    logic            reset_n_full;
    logic [3:0]      out_full_layer;

    logic [7:0]      data_out_end;
    
    // Preprocessing layer: flatten 2D features to 1D vector (748 features)
    pre_layer pre_layer_inst
    (
        .clk        (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m),
        .data_in    (data_out_P2),
        .addr_P2    (pre_addrb),
        .ren_P2     (ram_wen_P2),
        .ceb        (Y_ren),
        .dob        (pre_dob),
        .addrb      (pre_ram_raddr),
        .ren_Y748   (ren_Y748),
        .addrb_vga  (vga_rdaddr_P2[9:0]),
        .dob_vga    (data_out_pre)
    );
    
    // Fully connected layer 1: 748 features -> intermediate features
    conv1_layer1 u_conv1_layer
    (
        .clk        (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m && reset_n_conv1),
        .ren_Y748   (ren_Y748),
        .data_in    (pre_dob),
        .raddr      (pre_ram_raddr),
        .Y_ren      (Y_ren),
        .layer_ren  (layer_ren),
        .ram_addrb  (ram_raddr_conv2_layer),
        .ram_dob    (data_in1_conv2_layer),
        .ram_ceb    (Y_ren_conv2_layer),
        .reset_n    (reset_n_conv1)
    );
    
    // Fully connected layer 2: intermediate -> high-level features
    conv2_layer2 u_conv2_layer
    (
        .clk        (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m && reset_n_conv2),
        .ren_Y748   (layer_ren),
        .data_in    (data_in1_conv2_layer),
        .raddr      (ram_raddr_conv2_layer),
        .Y_ren      (Y_ren_conv2_layer),
        .layer_ren  (layer_ren_conv2_layer),
        .ram_addrb  (raddr_full_layer),
        .ram_dob    (in_full_layer),
        .ram_ceb    (Y_ren_full_layer),
        .reset_n    (reset_n_conv2)
    );
    
    // Output layer: high-level features -> 10 class outputs (0-9 digits)
    full_layer u_full_layer
    (
        .clk        (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m && reset_n_full),
        .layer_ren  (layer_ren_conv2_layer),
        .data_in    (in_full_layer),
        .data_out   (out_full_layer),
        .raddr      (raddr_full_layer),
        .read_flag  (Y_ren_full_layer),
        .reset_n    (reset_n_full)
    );
    
    // Display layer: convert recognition result (0-9) to VGA image format
    output_layer u_output_layer
    (
        .clk        (CLK_25MHZ),
        .rst_n      (r2_rstn_clk25m),
        .nub        (out_full_layer),
        .raddr      (vga_rdaddr_end),
        .TX         (data_out_end)
    );
    
    
    logic X; 
    logic Y;
    
    logic [18:0] pre_addrb;
    logic [15:0] vga_data_p1, vga_data_c1, vga_data_c2, vga_data_p2;
    
    // VGA read addresses for each layer
    logic [18:0]     vga_rdaddr_C1;
    logic [18:0]     vga_rdaddr_P1;
    logic [18:0]     vga_rdaddr_C2;
    logic [18:0]     vga_rdaddr_P2;
    logic [18:0]     vga_rdaddr_end;
    
    // Layer selection logic
    logic [2:0] layer_select;
    assign layer_select = 3'b101; // Default to P2 (change this to switch layers)
    // 001: C1, 010: P1, 011: C2, 100: P2, 101: Final
    
    // Mux for VGA data input
    logic [15:0] vga_data_mux;
    always_comb begin
        case(layer_select)
            3'b001: vga_data_mux = data_out_C1;
            3'b010: vga_data_mux = data_out_P1;
            3'b011: vga_data_mux = data_out_C2;
            3'b100: vga_data_mux = {data_out_pre[7:3], data_out_pre[7:2], data_out_pre[7:3]}; // P2 via pre_layer
            3'b101: vga_data_mux = {data_out_end[7:3], data_out_end[7:2], data_out_end[7:3]}; // Final
            default: vga_data_mux = 16'h0000;
        endcase
    end
    
    // Mux for VGA address output (distribute to layers)
    logic [18:0] vga_addr_out;
    assign vga_rdaddr_C1 = (layer_select == 3'b001) ? vga_addr_out : 0;
    assign vga_rdaddr_P1 = (layer_select == 3'b010) ? vga_addr_out : 0;
    assign vga_rdaddr_C2 = (layer_select == 3'b011) ? vga_addr_out : 0;
    assign vga_rdaddr_P2 = (layer_select == 3'b100) ? vga_addr_out : 0;
    assign vga_rdaddr_end = (layer_select == 3'b101) ? vga_addr_out : 0;
    
    // Display parameters based on layer
    logic [9:0] disp_width;
    logic [9:0] disp_height;
    logic [18:0] addr_max;
    
    always_comb begin
        case(layer_select)
            3'b001: begin disp_width = 98; disp_height = 78; addr_max = 7643; end // C1 (approx)
            3'b010: begin disp_width = 49; disp_height = 39; addr_max = 1910; end // P1
            3'b011: begin disp_width = 47; disp_height = 37; addr_max = 1738; end // C2
            3'b100: begin disp_width = 28; disp_height = 28; addr_max = 783; end  // P2 (28x28 for pre_layer)
            3'b101: begin disp_width = 28; disp_height = 28; addr_max = 783; end // Final
            default: begin disp_width = 0; disp_height = 0; addr_max = 0; end
        endcase
    end

assign vga_data_p1 = data_out_P1;
assign vga_data_c1 = data_out_C1;
assign vga_data_c2 = data_out_C2;
assign vga_data_p2 = data_out_P2;

    display_controller display_interface
    (
        .clk_pixel(CLK_25MHZ              ),
        .rst_n(r2_rstn_clk25m   ), 
        
        // Configuration inputs
        .i_disp_width(disp_width),
        .i_disp_height(disp_height),
        .i_addr_max(addr_max),
        
        // VGA timing signals
        .x_pos(X ),
        .y_pos(Y  ), 
        .vsync(o_top_vga_vsync    ),
        .hsync(o_top_vga_hsync    ), 
        .video_active(      ),
        
        // VGA RGB Pixel Data
        .red_out(o_top_vga_red   ),
        .green_out(o_top_vga_green    ),
        .blue_out(o_top_vga_blue      ), 
        .de_out(vde),                    // UPDATE: Added
        
        // VGA read/write from/to BRAM
        .pixel_data_in(vga_data_mux  ),  //o_bram_pix_data
        .pixel_addr_out( vga_addr_out    )    //o_bram_pix_addr   //addr_CV_C1   //addr_CV_C2   //pre_addrb
    );
    
    
    // UPDATE: ADD VGA to HDMI
    // NOTE: IF WE EXPAND TO 12 BIT COLOR REPRESENTATION, THIS IP MUST BE UPDATED
    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(CLK_25MHZ),  
        .pix_clkx5(CLK_125MHZ),
        .pix_clk_locked(locked),
        .rst(~r2_rstn_clk25m), // active high
        //Color and Sync Signals
        .red(o_top_vga_red), //o_top_vga_red
        .green(o_top_vga_green), //o_top_vga_green
        .blue(o_top_vga_blue), //o_top_vga_blue
        .hsync(o_top_vga_hsync),
        .vsync(o_top_vga_vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );
    
endmodule
