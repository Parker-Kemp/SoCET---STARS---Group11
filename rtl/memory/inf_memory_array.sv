// Generic parameterized inferred RAM using M9K embedded memory on the DE2-115 FPGA board.
// Single port, 1-cycle read latency (address in on one clock edge, data out after the next).
module inf_memory_array #(
    parameter int AS = 8, // array size
    parameter int MT = 32, // max tile size
    parameter int WORD_WIDTH = AS * 8, // Number of bits per word
    parameter int DEPTH = MT * MT * AS, // Number of words
    parameter int ADDR_WIDTH = $clog2(DEPTH) // Derived, do not override
)(
    input  logic CLK,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [WORD_WIDTH-1:0] data_in,
    input  logic wren, // write enable
    output logic [WORD_WIDTH-1:0] data_out
);
    // attribute forces Quartus to map this array to dedicated M9K blocks
    (* ramstyle = "M9K" *) logic [WORD_WIDTH-1:0] memory_array [DEPTH-1:0];
 
    // Synchronous write and synchronous read (standard M9K behavior).
    // Reading the address being written returns the OLD value.
    always_ff @(posedge CLK) begin
        if (wren) begin
            memory_array[addr] <= data_in;
        end
        data_out <= memory_array[addr];
    end
endmodule