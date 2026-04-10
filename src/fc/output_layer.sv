`timescale 1ns / 1ps

module output_layer (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [3:0] nub,
    input  logic [9:0] raddr,
    output logic [7:0] TX
);

    // Memory arrays for digits 0-9
    logic [7:0] T0 [0:783];
    logic [7:0] T1 [0:783];
    logic [7:0] T2 [0:783];
    logic [7:0] T3 [0:783];
    logic [7:0] T4 [0:783];
    logic [7:0] T5 [0:783];
    logic [7:0] T6 [0:783];
    logic [7:0] T7 [0:783];
    logic [7:0] T8 [0:783];
    logic [7:0] T9 [0:783];

    // Initialize memory arrays from files
    initial begin
            // Note: Update these paths to match your actual file locations
            $readmemh("D:/weights/0_20.txt", T0);
            $readmemh("D:/weights/0_21.txt", T1);
            $readmemh("D:/weights/0_22.txt", T2);
            $readmemh("D:/weights/0_23.txt", T3);
            $readmemh("D:/weights/0_24.txt", T4);
            $readmemh("D:/weights/0_25.txt", T5);
            $readmemh("D:/weights/0_26.txt", T6);
            $readmemh("D:/weights/0_27.txt", T7);
            $readmemh("D:/weights/0_28.txt", T8);
            $readmemh("D:/weights/0_29.txt", T9);
        end

    // Output selection logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            TX <= 8'b0;
        end else begin
            case (nub)
                4'd0: TX <= T0[raddr];
                4'd1: TX <= T1[raddr];
                4'd2: TX <= T2[raddr];
                4'd3: TX <= T3[raddr];
                4'd4: TX <= T4[raddr];
                4'd5: TX <= T5[raddr];
                4'd6: TX <= T6[raddr];
                4'd7: TX <= T7[raddr];
                4'd8: TX <= T8[raddr];
                4'd9: TX <= T9[raddr];
                default: TX <= 8'b0;
            endcase
        end
    end

endmodule
