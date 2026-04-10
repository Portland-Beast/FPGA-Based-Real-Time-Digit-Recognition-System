module ov7670_fsm (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic        i2c_busy,
    input  logic [7:0]  i2c_rdata,
    output logic [6:0]  i2c_addr,
    output logic [7:0]  i2c_wdata,
    output logic        i2c_ena,
    output logic        i2c_rw,
    output logic        ov7670_reset,
    output logic [7:0]  reg_value,
    output logic        config_finished,
    output logic        done
);

    localparam int C_ARTY_A7_CLK_FREQ = 100000000; // 100 MHz

//    logic [15:0] register_config_rom [0:80];

//    // Camera register initialization
//    initial begin
//        // Source: https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
//        // Modified for 100x80 resolution
//        register_config_rom[0]  = 16'h12_04; // set output format to RGB
//        register_config_rom[1]  = 16'h15_20; // pclk will not toggle during horizontal blank
//        register_config_rom[2]  = 16'h40_d0; // RGB565
//        register_config_rom[3]  = 16'h8C_00; // RGB444           //trial:close
//        register_config_rom[4]  = 16'h11_01;
//        register_config_rom[5]  = 16'h6B_4A;
//        register_config_rom[6]  = 16'h12_04; // COM7, set RGB color output (VGA base)
//        register_config_rom[7]  = 16'h0C_04; // COM3, enable DCW (downsample/crop/window) - CHANGED
//        register_config_rom[8]  = 16'h3E_19; // COM14, enable scaling + manual scaling - CHANGED
//        register_config_rom[9]  = 16'h04_00; // COM1, disable CCIR656
//        register_config_rom[10] = 16'h40_d0; // COM15, RGB565, full output range
//        register_config_rom[11] = 16'h3a_04; // TSLB set correct output data sequence (magic)
//        register_config_rom[12] = 16'h14_18; // COM9 MAX AGC value x4
//        register_config_rom[13] = 16'h4F_B3; // MTX1 magical matrix coefficients
//        register_config_rom[14] = 16'h50_B3; // MTX2
//        register_config_rom[15] = 16'h51_00; // MTX3
//        register_config_rom[16] = 16'h52_3d; // MTX4
//        register_config_rom[17] = 16'h53_A7; // MTX5
//        register_config_rom[18] = 16'h54_E4; // MTX6
//        register_config_rom[19] = 16'h58_9E; // MTXS
//        register_config_rom[20] = 16'h3D_C0; // COM13 sets gamma enable
//        register_config_rom[21] = 16'h17_16; // HSTART - adjusted for 100 width - CHANGED
//        register_config_rom[22] = 16'h18_04; // HSTOP - adjusted for 100 width - CHANGED
//        register_config_rom[23] = 16'h32_80; // HREF edge offset
//        register_config_rom[24] = 16'h19_02; // VSTART - adjusted for 80 height - CHANGED
//        register_config_rom[25] = 16'h1A_7a; // VSTOP - adjusted for 80 height - CHANGED
//        register_config_rom[26] = 16'h03_0A; // VREF vsync edge offset
//        register_config_rom[27] = 16'h0F_41; // COM6 reset timings
//        register_config_rom[28] = 16'h1E_00; // MVFP disable mirror/flip
//        register_config_rom[29] = 16'h33_0B; // CHLF magic value
//        register_config_rom[30] = 16'h3C_78; // COM12 no HREF when VSYNC low
//        register_config_rom[31] = 16'h69_00; // GFIX fix gain control
//        register_config_rom[32] = 16'h74_00; // REG74 Digital gain control
//        register_config_rom[33] = 16'hB0_84; // RSVD magic value (required for good color)
//        register_config_rom[34] = 16'hB1_0c; // ABLC1
//        register_config_rom[35] = 16'hB2_0e; // RSVD more magic values
//        register_config_rom[36] = 16'hB3_80; // THL_ST mystery scaling numbers
//        register_config_rom[37] = 16'h70_3a; // Scaling parameters
//        register_config_rom[38] = 16'h71_35;     
//        register_config_rom[39] = 16'h72_11;
//        register_config_rom[40] = 16'h73_f1; // Changed for aggressive scaling - CHANGED
//        register_config_rom[41] = 16'ha2_52; // Scaling factor - CHANGED
//        register_config_rom[42] = 16'h7a_20; // gamma curve values
//        register_config_rom[43] = 16'h7b_1c; // Adjusted - CHANGED
//        register_config_rom[44] = 16'h7c_28; // Adjusted - CHANGED
//        register_config_rom[45] = 16'h7d_3c; // Adjusted - CHANGED
//        register_config_rom[46] = 16'h7e_5a;
//        register_config_rom[47] = 16'h7f_69;
//        register_config_rom[48] = 16'h80_76;
//        register_config_rom[49] = 16'h81_80;
//        register_config_rom[50] = 16'h82_88;
//        register_config_rom[51] = 16'h83_8f;
//        register_config_rom[52] = 16'h84_96;
//        register_config_rom[53] = 16'h85_a3;
//        register_config_rom[54] = 16'h86_af;
//        register_config_rom[55] = 16'h87_c4;
//        register_config_rom[56] = 16'h88_d7;
//        register_config_rom[57] = 16'h89_e8; // AGC and AEC
//        register_config_rom[58] = 16'h13_e0; // COM8, disable AGC/AEC
//        register_config_rom[59] = 16'h00_00; // set gain reg to 0 for AGC
//        register_config_rom[60] = 16'h10_00; // set ARCJ reg to 0
//        register_config_rom[61] = 16'h0d_40; // magic reserved bit for COM4
//        register_config_rom[62] = 16'h14_18; // COM9, 4x gain + magic bit
//        register_config_rom[63] = 16'ha5_05; // BD50MAX
//        register_config_rom[64] = 16'hab_07; // DB60MAX
//        register_config_rom[65] = 16'h24_95; // AGC upper limit
//        register_config_rom[66] = 16'h25_33; // AGC lower limit
//        register_config_rom[67] = 16'h26_e3; // AGC/AEC fast mode op region
//        register_config_rom[68] = 16'h9f_78; // HAECC1
//        register_config_rom[69] = 16'ha0_68; // HAECC2
//        register_config_rom[70] = 16'ha1_0b; // magic - CHANGED
//        register_config_rom[71] = 16'ha6_d8; // HAECC3
//        register_config_rom[72] = 16'ha7_d8; // HAECC4
//        register_config_rom[73] = 16'ha8_f0; // HAECC5
//        register_config_rom[74] = 16'ha9_90; // HAECC6
//        register_config_rom[75] = 16'haa_94; // HAECC7
//        register_config_rom[76] = 16'h13_e5; // COM8, enable AGC/AEC
//        register_config_rom[77] = 16'h69_06; // gain of RGB (manually adjusted)
//        register_config_rom[78] = 16'h74_19; // Additional scaling control - ADDED
//        register_config_rom[79] = 16'h9a_80; // Additional scaling - ADDED
//        register_config_rom[80] = 16'h43_14; // Reserved scaling - ADDED
//    end


    logic [15:0] register_config_rom [0:72];
// Correct rgb565
    initial begin
        register_config_rom[0]  = 16'h12_80;
        register_config_rom[1]  = 16'h11_80;
        register_config_rom[2]  = 16'h0c_04;
        register_config_rom[3]  = 16'h3e_1a;
        register_config_rom[4]  = 16'h12_04;
        register_config_rom[5]  = 16'h40_d0;
        register_config_rom[6]  = 16'h3a_04;
        register_config_rom[7]  = 16'h3D_C0;
        register_config_rom[8]  = 16'h04_00;
        register_config_rom[9]  = 16'h70_3a;
        register_config_rom[10] = 16'h71_35;
        register_config_rom[11] = 16'h72_22;
        register_config_rom[12] = 16'h73_f2;
        register_config_rom[13] = 16'ha2_02;
        register_config_rom[14] = 16'h17_18;
        register_config_rom[15] = 16'h18_06;
        register_config_rom[16] = 16'h32_24;
        register_config_rom[17] = 16'h19_02;
        register_config_rom[18] = 16'h1a_7a;
        register_config_rom[19] = 16'h03_00;
        register_config_rom[20] = 16'h4F_B3;
        register_config_rom[21] = 16'h50_B3;
        register_config_rom[22] = 16'h51_00;
        register_config_rom[23] = 16'h52_3d;
        register_config_rom[24] = 16'h53_A7;
        register_config_rom[25] = 16'h54_E4;
        register_config_rom[26] = 16'h58_9E;
        register_config_rom[27] = 16'h13_e0;
        register_config_rom[28] = 16'h15_20;
        register_config_rom[29] = 16'h0F_41;
        register_config_rom[30] = 16'h3C_78;
        register_config_rom[31] = 16'h00_00;
        register_config_rom[32] = 16'h10_00;
        register_config_rom[33] = 16'h0d_40;
        register_config_rom[34] = 16'h14_18;
        register_config_rom[35] = 16'h24_95;
        register_config_rom[36] = 16'h25_33;
        register_config_rom[37] = 16'h26_e3;
        register_config_rom[38] = 16'h9f_78;
        register_config_rom[39] = 16'ha0_68;
        register_config_rom[40] = 16'ha1_03;
        register_config_rom[41] = 16'ha6_d8;
        register_config_rom[42] = 16'ha7_d8;
        register_config_rom[43] = 16'ha8_f0;
        register_config_rom[44] = 16'ha9_90;
        register_config_rom[45] = 16'haa_94;
        register_config_rom[46] = 16'hB0_84;
        register_config_rom[47] = 16'hB1_0c;
        register_config_rom[48] = 16'hB2_0e;
        register_config_rom[49] = 16'hB3_80;
        register_config_rom[50] = 16'h33_0B;
        register_config_rom[51] = 16'h69_00;
        register_config_rom[52] = 16'h7a_20;
        register_config_rom[53] = 16'h7b_10;
        register_config_rom[54] = 16'h7c_1e;
        register_config_rom[55] = 16'h7d_35;
        register_config_rom[56] = 16'h7e_5a;
        register_config_rom[57] = 16'h7f_69;
        register_config_rom[58] = 16'h80_76;
        register_config_rom[59] = 16'h81_80;
        register_config_rom[60] = 16'h82_88;
        register_config_rom[61] = 16'h83_8f;
        register_config_rom[62] = 16'h84_96;
        register_config_rom[63] = 16'h85_a3;
        register_config_rom[64] = 16'h86_af;
        register_config_rom[65] = 16'h87_c4;
        register_config_rom[66] = 16'h88_d7;
        register_config_rom[67] = 16'h89_e8;
        register_config_rom[68] = 16'ha5_05;
        register_config_rom[69] = 16'hab_07;
        register_config_rom[70] = 16'h13_e5;
        register_config_rom[71] = 16'h1E_23;
        register_config_rom[72] = 16'h69_06;
    end





    // Type declaration
    typedef enum logic [3:0] {
        POWERUP,
        IDLE,
        RESET_DEVICE,
        I2C_WRITE_REGISTER,
        WAIT_BETWEEN_TX,
        I2C_WRITE_READ_REGISTER_ADDRESS,
        WAIT_1US,
        I2C_READ_REG,
        WAIT_1US_AFTER_READ
    } state_t;

    // Signals
    localparam logic I2C_READ = 1'b1;
    localparam logic I2C_WRITE = 1'b0;
    localparam logic [6:0] OV7670_ADDR = 7'b0100001;

    localparam int CLK_CNT_600MS = (C_ARTY_A7_CLK_FREQ / 10) * 6;
    localparam int CLK_CNT_1MS = (C_ARTY_A7_CLK_FREQ / 1000);
    localparam int CLK_CNT_1US = (C_ARTY_A7_CLK_FREQ / 1000000);

    logic reset_busy_cnt;
    logic ov7670_reset_sig;
    logic [15:0] register_config;
    logic i2c_busy_edge;

    typedef struct packed {
        state_t       state;
        int           counter;
        logic         i2c_ena;
        logic [7:0]   read;
        logic         done;
        logic         config_finished;
        int           rom_index;
    } reg_t;

    typedef struct packed {
        logic         busy;
        int           busy_cnt;
    } i2c_reg_t;

    localparam reg_t INIT_REG_FILE = '{
        state: POWERUP,
        counter: 0,
        i2c_ena: 1'b0,
        read: '0,
        done: 1'b0,
        config_finished: 1'b0,
        rom_index: 0
    };

    localparam i2c_reg_t INIT_I2C_REGS = '{
        busy: 1'b0,
        busy_cnt: 0
    };

    reg_t r, r_next;
    i2c_reg_t i2c_r, i2c_next;

    // UPDATE: Edge detection for start signal
    logic start_prev;
    always_ff @(posedge clk) begin
        if (rst) start_prev <= 1'b0;
        else start_prev <= start;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            r <= INIT_REG_FILE;
            i2c_r <= INIT_I2C_REGS;
        end else begin
            r <= r_next;
            i2c_r <= i2c_next;
        end
    end

    always_comb begin
        r_next = r;

        i2c_rw = 1'b0;
        reset_busy_cnt = 1'b0;
        i2c_wdata = '0;
        ov7670_reset_sig = 1'b1;

        case (r.state)
            POWERUP: begin // wait 600ms for device to powerup 
                r_next.counter = r.counter + 1;
                if (r.counter == CLK_CNT_600MS - 1) begin
                    r_next.counter = 0;
                    reset_busy_cnt = 1'b1;
                    r_next.state = RESET_DEVICE;
                end
            end

            IDLE: begin
                if (start == 1'b1 && start_prev == 1'b0) begin // UPDATE: Rising edge detection
                    r_next.rom_index = 0;
                    r_next.config_finished = 1'b0;
                    r_next.state = RESET_DEVICE;
                end
            end

            RESET_DEVICE: begin
                r_next.counter = r.counter + 1;
                if (r.counter < CLK_CNT_600MS / 2) begin
                    ov7670_reset_sig = 1'b0; // active low reset
                end

                if (r.counter == CLK_CNT_600MS) begin
                    r_next.counter = 0; // reset counter
                    r_next.state = I2C_WRITE_REGISTER; // 600ms over
                    reset_busy_cnt = 1'b1;
                end
            end

            I2C_WRITE_REGISTER: begin
                case (i2c_r.busy_cnt)
                    0: begin
                        r_next.i2c_ena = 1'b1; // start i2c transaction
                        i2c_rw = I2C_WRITE;
                        i2c_wdata = register_config[15:8]; // register address
                    end
                    1: begin
                        i2c_wdata = register_config[7:0]; // register value
                    end
                    2: begin
                        r_next.i2c_ena = 1'b0;
                        if (i2c_busy == 1'b0) begin // i2c transaction completed 
                            reset_busy_cnt = 1'b1; // reset busy_cnt register
                            r_next.state = WAIT_BETWEEN_TX;
                        end
                    end
                    default: ;
                endcase
            end

            WAIT_BETWEEN_TX: begin // waits for 1ms between write and read
                r_next.counter = r.counter + 1;

                if (r.counter == CLK_CNT_1MS - 1) begin
                    r_next.counter = 0;
                    if (r.rom_index < $size(register_config_rom) - 1) begin
                        r_next.rom_index = r.rom_index + 1;
                        r_next.state = I2C_WRITE_REGISTER;
                    end else begin
                        r_next.rom_index = 0;
                        r_next.config_finished = 1'b1;
                        r_next.state = I2C_WRITE_READ_REGISTER_ADDRESS;
                    end
                end
            end

            I2C_WRITE_READ_REGISTER_ADDRESS: begin
                case (i2c_r.busy_cnt)
                    0: begin
                        r_next.i2c_ena = 1'b1;
                        i2c_rw = I2C_WRITE;
                        i2c_wdata = register_config[15:8];
                    end
                    1: begin
                        r_next.i2c_ena = 1'b0;
                        if (i2c_busy == 1'b0) begin
                            r_next.counter = 0;
                            r_next.state = WAIT_1US;
                            reset_busy_cnt = 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            WAIT_1US: begin // wait 1us between write register address and read register value
                r_next.counter = r.counter + 1;
                if (r.counter == CLK_CNT_1US - 1) begin
                    r_next.counter = 0;
                    r_next.state = I2C_READ_REG;
                    reset_busy_cnt = 1'b1;
                end
            end

            I2C_READ_REG: begin
                case (i2c_r.busy_cnt)
                    0: begin
                        r_next.i2c_ena = 1'b1;
                        i2c_rw = I2C_READ;
                    end
                    1: begin
                        i2c_rw = I2C_READ;
                        if (i2c_busy == 1'b0) begin
                            r_next.done = 1'b1;
                            r_next.read = i2c_rdata;
                            r_next.i2c_ena = 1'b0;
                            r_next.state = WAIT_1US_AFTER_READ;
                            reset_busy_cnt = 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            WAIT_1US_AFTER_READ: begin // wait 1us between write register address and read register value
                r_next.done = 1'b0;
                r_next.counter = r.counter + 1;

                if (r.counter >= CLK_CNT_1US - 1) begin
                    r_next.counter = r.counter;

                    if (r.rom_index < $size(register_config_rom) - 1) begin
                        r_next.rom_index = r.rom_index + 1;
                        reset_busy_cnt = 1'b1;
                        r_next.counter = 0;
                        r_next.state = I2C_WRITE_READ_REGISTER_ADDRESS;
                    end else begin
                        r_next.counter = 0;
                        r_next.state = IDLE;
                    end
                end
            end

            default: begin
                r_next.state = IDLE;
            end
        endcase
    end

    always_comb begin
        if (reset_busy_cnt == 1'b1) begin
            i2c_next.busy_cnt = 0;
        end else if (i2c_busy_edge == 1'b1) begin
            i2c_next.busy_cnt = i2c_r.busy_cnt + 1;
        end else begin
            i2c_next.busy_cnt = i2c_r.busy_cnt;
        end
        i2c_next.busy = i2c_busy; // captures the current value of the busy signal in the busy register
    end

    assign i2c_busy_edge = (i2c_r.busy == 1'b0 && i2c_busy == 1'b1) ? 1'b1 : 1'b0; // detects the rising_edge of the busy signal from the i2c_master
    assign i2c_addr = OV7670_ADDR;

    assign reg_value = r.read;

    assign register_config = register_config_rom[r.rom_index];

    assign i2c_ena = r.i2c_ena;
    assign done = r.done;

    assign config_finished = r.config_finished;

    assign ov7670_reset = ov7670_reset_sig;

endmodule
