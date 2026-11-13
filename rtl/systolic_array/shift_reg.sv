module shift_reg #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input logic CLK,
    input logic nRST, // Active-low synchronous reset
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    generate
        if (DEPTH == 0) begin : gen_pass_through // buffer for if DEPTH is 0
            assign data_out = data_in;
        end else begin : gen_shift_reg
            logic [WIDTH-1:0] pipe [0:DEPTH-1];

            always_ff @(posedge CLK, negedge nRST) begin
                if (!nRST) begin
                    for (int i = 0; i < DEPTH; i++) begin
                        pipe[i] <= '0;
                    end
                end else begin
                    pipe[0] <= data_in;
                    for (int i = 1; i < DEPTH; i++) begin
                        pipe[i] <= pipe[i-1];
                    end
                end
            end

            assign data_out = pipe[DEPTH-1];
        end
    endgenerate

endmodule
