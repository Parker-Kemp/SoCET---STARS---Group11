module tiling_controller #(
    parameter AS  = 8, // ARRAY_SIZE, cells per side = tile width. TODO: make power of two for things to work smoothly
    parameter MAX = 20 // largest supported matrix dimension (TODO: placeholder until we know the board's memory
) (
    logic CLK, nRST
);

    localparam MAX_TILES = (MAX + AS - 1) / AS;
    localparam AS_POWER  = $clog2(AS);
    // TODO: I will add the feeder and writer here with interface to memory.

    // calculates tiles. TODO: Connect to both modules
    let tiles(length) = (length >> AS_POWER) + |length[AS_POWER-1:0];

endmodule
