module systolic_array #(
    parameter AS     = 4,
    parameter DATA_W = 8,
    parameter ACC_W  = 32
) (
    input  logic CLK,
    input  logic nRST,
    input  logic flag_in, // one bit, not one per row
    input  logic signed [DATA_W-1:0] a_row_in [AS], // A[0][k] .. A[AS-1][k], all on the same cycle
    input  logic signed [DATA_W-1:0] b_col_in [AS], // B[k][0] .. B[k][AS-1], all on the same cycle
    output logic signed [ACC_W-1:0]  c_out [AS][AS],
    output logic exit_flag
);
    logic signed [DATA_W-1:0] a_row_array [AS];
    logic signed [DATA_W-1:0] b_col_array [AS];
    logic flag_in_array [AS];

    genvar i; // r or c. 
    generate
        for (i = 0; i < AS; i++) begin
            // SHIFT REGISTERS FOR A
            shift_reg #(
                .WIDTH(DATA_W),
                .DEPTH(i)
             ) shift_reg_a (
                .CLK     (CLK),
                .nRST    (nRST),
                .data_in (a_row_in[i]),
                .data_out(a_row_array[i])
            );

            // SHIFT REGISTERS FOR B
            shift_reg #(
                .WIDTH(DATA_W),
                .DEPTH(i)
             ) shift_reg_b (
                .CLK     (CLK),
                .nRST    (nRST),
                .data_in (b_col_in[i]),
                .data_out(b_col_array[i]) // signed vs unsigned doesn't matter in this case
            );

            // SHIFT REGISTERS FOR FLAG
            shift_reg #(
                .WIDTH(1),
                .DEPTH(i)
             ) shift_reg_flag (
                .CLK     (CLK),
                .nRST    (nRST),
                .data_in (flag_in),
                .data_out(flag_in_array[i])
            );
        end
    endgenerate

    // ARRAY GRID, WILL BE CONNECTED TO STAGGERING
    array_grid #(
        .AS    (AS),
        .DATA_W(DATA_W /* default 8 */),
        .ACC_W (ACC_W /* default 32 */)
    ) array_grid (
        .CLK      (CLK),
        .nRST     (nRST),
        .flag_in  (flag_in_array),
        .a_row_in (a_row_array),
        .b_col_in (b_col_array),
        .c_out    (c_out),
        .exit_flag(exit_flag)
    );
    
endmodule
