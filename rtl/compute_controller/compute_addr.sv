// calculates the addr using a formula
module compute_addr #(
    parameter AS = 8
) (
    input logic CLK, nRST, clear,
    input logic [7:0] inner_tile_count,
    input logic [7:0] in_tile_count,
    input logic [7:0] tiles,
    input logic grow_en,
    output logic [15 + $clog2(AS):0] addr
);

    logic [15: 0] base = '0;

    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST || clear) begin
            base <= 0;
        end else if (grow_en) begin
            base <= base + 16'(tiles);
        end
    end

    assign addr = ((base + 16'(inner_tile_count)) << $clog2(AS)) + 16'(in_tile_count);
    
endmodule
