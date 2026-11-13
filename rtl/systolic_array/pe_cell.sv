module pe_cell #(parameter DATA_W = 8, parameter ACC_W = 32)
(
    input logic CLK,
    input logic nRST,
    input logic flag_in,
    input logic signed [DATA_W-1:0] a_in,
    input logic signed [DATA_W-1:0] b_in,
    output logic flag_out,
    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic signed [ACC_W-1:0] out_reg
);  
    logic signed [ACC_W-1:0] running_sum;

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
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
            // flag check and summation
            if (flag_in) begin
                out_reg     <= running_sum;               
                running_sum <= a_in * b_in;              
            end else begin
                running_sum <= running_sum + (a_in * b_in); 
            end
        end
    end

endmodule 