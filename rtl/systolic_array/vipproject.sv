module highlevel #(parameter N = 4, parameter DATA_W = 8, parameter ACC_W = 32)(
    input logic clk,
    input logic enablesafe,
    input logic nrst,
    input logic flag_in [N], 
    input logic signed [DATA_W-1:0] a_row_in [N], 
    input logic signed [DATA_W-1:0] b_col_in [N],   
    output logic signed [ACC_W-1:0] sums [N][N],
    output logic signed [ACC_W-1:0] c_out [N][N]
);

    logic signed [7:0] a_wire [4][4];
    logic signed [7:0] b_wire [4][4];
    logic              f_wire [4][4];

    // Loop for 4x4 grid of Processing Elements (rows 0..3, cols 0..3)
    genvar r, c;
    generate
        for (r = 0; r < 4; r++) begin : row
            for (c = 0; c < 4; c++) begin : col
                
                lowlevel pe (
                    .clk         (clk),
                    .nrst        (nrst),
                    // If first col (c==0), take external input; else take left neighbor's output
                    .flag_in     (c == 0 ? flag_in[r]  : f_wire[r][c-1]),
                    .enablesafe  (enablesafe),
                    .a_in        (c == 0 ? a_row_in[r] : a_wire[r][c-1]),
                    // If first row (r==0), take external input; else take top neighbor's output
                    .b_in        (r == 0 ? b_col_in[c] : b_wire[r-1][c]),
                    // Send outputs to right and bottom wires
                    .flag_out    (f_wire[r][c]),
                    .a_out       (a_wire[r][c]),
                    .b_out       (b_wire[r][c]),
                    .running_sum (sums[r][c]),
                    .out_reg     (c_out[r][c])
                );

            end
        end
    endgenerate
    //dont have input stagger on high level yet- will add soon. - maybe controller will add//
endmodule 

module lowlevel #(parameter DATA_W = 8, parameter ACC_W = 32)
(
    input logic clk,
    input logic nrst,
    input logic flag_in,
    input logic enablesafe,
    input logic signed [DATA_W-1:0] a_in,
    input logic signed [DATA_W-1:0] b_in,
    output logic flag_out,
    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic signed [ACC_W-1:0] running_sum,
    output logic signed [ACC_W-1:0] out_reg
);  

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst |!enablesafe) begin
            a_out       <= '0;
            b_out       <= '0;
            flag_out    <= 1'b0;
            running_sum <= '0;
            out_reg     <= '0;
        end else begin
            // Pass
            a_out    <= a_in;
            b_out    <= b_in;
            flag_out <= flag_in;
            // flag check
            if (flag_in) begin
                out_reg     <= running_sum;               
                running_sum <= a_in * b_in;              
            end else begin
                running_sum <= running_sum + (a_in * b_in); 
            end
        end
    end

endmodule 