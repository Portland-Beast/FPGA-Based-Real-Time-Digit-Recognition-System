`timescale 1ns / 1ps

// Fully connected layer with comparison module
// Performs fully connected computation and max comparison, outputs digit recognition (0-9)

module full_layer (
    // System clock and reset
    input  logic                clk,
    input  logic                rst_n,

    // Input interface
    input  logic                layer_ren,      // Read enable signal
    input  logic signed [11:0]  data_in,        // Input data

    // Output interface
    output logic [3:0]          data_out,       // Output digit 0-9
    output logic [6:0]          raddr,          // Read address
    output logic                read_flag,      // Read enable flag

    // Reset control
    output logic                reset_n         // Reset output
);

    // Internal registers
    logic [5:0]                 cnt_48;         // Counter for weight address 0-47
    logic [3:0]                 cnt_10;         // Counter for bias address 0-9
    logic [1:0]                 cnt_4;          // Counter for comparison timing 0-3
    logic                       layer_ren_fft1;
    logic                       layer_ren_fft2;
    logic                       calc_flag;
    logic                       compare_flag;
    logic                       compare_flag_fft1;

    // Weights and biases
    logic signed [7:0]          weight [0:479];
    logic signed [7:0]          bias [0:9];

    // Computation related
    logic signed [19:0]         calc_out;
    logic signed [19:0]         mult_result;     // Pipeline register for multiplication
    logic signed [11:0]         data_in_reg;     // Pipeline register for data_in
    logic signed [7:0]          weight_reg;      // Pipeline register for weight
    logic signed [11:0]         buffer;
    logic signed [11:0]         max;
    logic [3:0]                 nub;

    // Initialize weights and biases
    initial begin
        $readmemh("D:/weights/fc_weight.txt", weight);
        $readmemh("D:/weights/fc_bias.txt", bias);
    end

    // Main control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            cnt_48              <= '0;
            cnt_10              <= '0;
            cnt_4               <= '0;
            read_flag           <= 1'b0;
            calc_out            <= '0;
            mult_result         <= '0;
            data_in_reg         <= '0;
            weight_reg          <= '0;
            layer_ren_fft1      <= 1'b0;
            layer_ren_fft2      <= 1'b0;
            raddr               <= '0;
            calc_flag           <= 1'b0;
            compare_flag        <= 1'b0;
            compare_flag_fft1   <= 1'b0;
            max                 <= '0;
            buffer              <= '0;
            data_out            <= '0;
        end
        else begin
            layer_ren_fft1      <= layer_ren;
            layer_ren_fft2      <= layer_ren_fft1;
            compare_flag_fft1   <= compare_flag;

            // Set read_flag on falling edge of layer_ren_fft1 or compare_flag
            begin
                if (layer_ren_fft1 != layer_ren_fft2 && layer_ren_fft2 == 1)
                    read_flag <= 1'b1;

                if (compare_flag_fft1 != compare_flag && compare_flag_fft1 == 1 && cnt_10 != 10) begin
                    read_flag <= 1'b1;
                end

                if (compare_flag_fft1 != compare_flag && compare_flag_fft1 == 1 && cnt_10 == 10) begin
                    data_out    <= nub;
                    cnt_10      <= '0;
                end

                if (raddr == 47) begin          // Close read after 47 reads
                    read_flag <= 1'b0;
                end

                if (cnt_48 == 47) begin         // Close calc after 47 calculations
                    calc_flag       <= 1'b0;
                    compare_flag    <= 1'b1;
                end

                if (cnt_4 == 3) begin           // Close compare after 3 comparisons
                    calc_out        <= '0;
                    compare_flag    <= 1'b0;
                end
            end

            // Calculate raddr when read_flag is 1
            if (read_flag == 1'b1) begin
                calc_flag <= 1'b1;

                begin
                    if (raddr == 47) begin
                        raddr <= '0;
                    end
                    else begin
                        raddr <= raddr + 1;
                    end
                end
            end

            // Pipeline stage 1: Register data and weight
            if (calc_flag == 1'b1 || read_flag == 1'b1) begin
                data_in_reg <= data_in;
                weight_reg <= weight[cnt_48 + 48 * cnt_10];
            end
            
            // Pipeline stage 2: Multiplication
            mult_result <= data_in_reg * weight_reg;
            
            // Pipeline stage 3: Accumulate calculation when calc_flag is 1
            if (calc_flag == 1'b1) begin
                calc_out <= calc_out + mult_result;

                if (cnt_48 == 47) begin
                    cnt_48  <= '0;
                    cnt_10  <= cnt_10 + 1;
                end
                else
                    cnt_48 <= cnt_48 + 1;
            end

            // Compare values
            if (compare_flag == 1'b1) begin
                if (cnt_4 == 0) begin
                    calc_out <= calc_out + bias[cnt_10 - 1];
                end

                buffer <= calc_out[18:7];

                if (cnt_10 == 1) begin
                    max <= calc_out[18:7];
                end

                if (max < buffer) begin
                    max <= buffer;
                    nub <= cnt_10 - 1;
                end

                if (cnt_4 == 3) begin
                    cnt_4 <= '0;
                end
                else
                    cnt_4 <= cnt_4 + 1;
            end
        end
    end

    // Reset control
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            reset_n <= 1'b1;
        end
        else if (compare_flag_fft1 != compare_flag && compare_flag_fft1 == 1 && cnt_10 == 10)
            reset_n <= 1'b0;
    end

endmodule
