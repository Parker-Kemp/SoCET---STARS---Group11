module array_grid #(
    parameter AS = 8,
    parameter DATA_W = 8,
    parameter ACC_W = 32
) (
    input logic CLK,
    input logic nRST,
    input logic flag_in [AS], 
    input logic signed [DATA_W-1:0] a_row_in [AS], 
    input logic signed [DATA_W-1:0] b_col_in [AS],
    output logic signed [ACC_W-1:0] c_out [AS][AS],
    output logic exit_flag
);

    logic signed [DATA_W-1:0] a_wire [AS][AS]; // wire passing valules to the right
    logic signed [DATA_W-1:0] b_wire [AS][AS]; // wire passing values to the bottom
    logic                     flag_wire [AS][AS]; // wire passing the flag

    // Loop for 4x4 grid of Processing Elements (rows 0..3, cols 0..3)
    genvar r, c;
    generate
        for (r = 0; r < AS; r++) begin : row
            for (c = 0; c < AS; c++) begin : col
                pe_cell pe_cell (
                    .CLK         (CLK),
                    .nRST        (nRST),
                    // If first col (c==0), take external input; else take left neighbor's output
                    .flag_in     (c == 0 ? flag_in[r]  : flag_wire[r][c-1]),
                    .a_in        (c == 0 ? a_row_in[r] : a_wire[r][c-1]),
                    // If first row (r==0), take external input; else take top neighbor's output
                    .b_in        (r == 0 ? b_col_in[c] : b_wire[r-1][c]),
                    // Send outputs to right and bottom wires
                    .flag_out    (flag_wire[r][c]),
                    .a_out       (a_wire[r][c]),
                    .b_out       (b_wire[r][c]),
                    .out_reg     (c_out[r][c])
                );

            end
        end
    endgenerate

    assign exit_flag = flag_wire[AS-1][AS-1];
endmodule 
