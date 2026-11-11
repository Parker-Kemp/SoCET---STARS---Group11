// Three separate RAM blocks (A, B, C) so all three can be accessed in the same cycle.
// One word = one row/column slice of a tile = AS values.
// Depth is set by MT (max tiles per matrix side), so largest matrix side = MT * AS.
module multi_block_ram #(
    parameter int AS = 8, // array side length
    parameter int MT = 32, // max tiles per matrix side (32 * 8 = 256)
    parameter int WORD_WIDTH_AB = 8 * AS,
    parameter int WORD_WIDTH_C = 32 * AS,
    parameter int DEPTH = MT * MT * AS, // words per block (same for A, B and C)
    parameter int ADDR_WIDTH = $clog2(DEPTH) // 13 bits for MT = 32, AS = 8
) (
    input logic CLK,
 
    // signals for Block A
    input logic [ADDR_WIDTH-1:0] addr_a,
    input logic [WORD_WIDTH_AB-1:0] data_in_a,
    input logic wren_a, // write enable
    output logic [WORD_WIDTH_AB-1:0] data_out_a,
 
    // signals for Block B
    input logic [ADDR_WIDTH-1:0] addr_b,
    input logic [WORD_WIDTH_AB-1:0] data_in_b,
    input logic wren_b, // write enable
    output logic [WORD_WIDTH_AB-1:0] data_out_b,
 
    // signals for Block C
    input logic [ADDR_WIDTH-1:0] addr_c,
    input logic [WORD_WIDTH_C-1:0] data_in_c,
    input logic wren_c, // write enable
    output logic [WORD_WIDTH_C-1:0] data_out_c
);
 
    // Block A
    inf_memory_array #(
        .WORD_WIDTH(WORD_WIDTH_AB),
        .DEPTH     (DEPTH)
    ) mem_block_a (
        .CLK     (CLK),
        .addr    (addr_a),
        .data_in (data_in_a),
        .wren    (wren_a),
        .data_out(data_out_a)
    );
 
    // Block B
    inf_memory_array #(
        .WORD_WIDTH(WORD_WIDTH_AB),
        .DEPTH     (DEPTH)
    ) mem_block_b (
        .CLK     (CLK),
        .addr    (addr_b),
        .data_in (data_in_b),
        .wren    (wren_b),
        .data_out(data_out_b)
    );
 
    // Block C
    inf_memory_array #(
        .WORD_WIDTH(WORD_WIDTH_C),
        .DEPTH     (DEPTH)
    ) mem_block_c (
        .CLK     (CLK),
        .addr    (addr_c),
        .data_in (data_in_c),
        .wren    (wren_c),
        .data_out(data_out_c)
    );
 
endmodule
