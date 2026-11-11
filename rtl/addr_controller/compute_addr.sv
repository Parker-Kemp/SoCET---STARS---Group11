// Calculates a RAM address: {tile index, position inside the tile}.
// Same as ((base + inner_tile_count) << $clog2(AS)) + in_tile_count.
// AS must be a power of 2.
module compute_addr #(
    parameter int AS = 8, // array side length
    parameter int MT = 32, // max tiles per matrix side
    // Derived widths, DO NOT OVERRIDE
    parameter int TILES_W = $clog2(MT + 1), // 6: holds 1 to 32
    parameter int TILE_W = $clog2(MT), // 5: counts 0 to 31
    parameter int IN_TILE_W = $clog2(AS), // 3: counts 0 to AS-1
    parameter int BASE_W = $clog2(MT * MT), // 10: tile index 0 to 1023
    parameter int ADDR_W = $clog2(MT * MT * AS) // 13
) (
    input  logic CLK, nRST,
    input  logic clear,            // synchronous clear
    input  logic grow_en,
    input  logic [TILES_W-1:0] tiles,
    input  logic [TILE_W-1:0] inner_tile_count,
    input  logic [IN_TILE_W-1:0] in_tile_count,
    output logic [ADDR_W-1:0] addr
);

    logic [BASE_W-1:0] base;
    logic [BASE_W-1:0] tile_index;

    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            base <= '0;
        end else if (clear) begin
            base <= '0;
        end else if (grow_en) begin
            base <= base + BASE_W'(tiles);
        end
    end

    assign tile_index = base + BASE_W'(inner_tile_count);
    assign addr = {tile_index, in_tile_count};

endmodule
