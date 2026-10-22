module tiling_controller #(
    parameter AS  = 8, // ARRAY_SIZE, cells per side = tile width. Must be power of two for things to work smoothly
    parameter MAX = 20 // largest supported matrix dimension (placeholder until we know the board's memory
) (
    logic CLK, nRST
);

    // TODO: I will add the feeder and writer here with interface to memory.

endmodule