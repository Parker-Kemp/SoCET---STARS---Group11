// This module just merges the feeder and writer.
module addr_controller #(
    parameter int AS = 8, // array side length
    parameter int MT = 32, // max tiles per matrix side (32 * 8 = 256)
    parameter int DEPTH = MT * MT * AS, // words per block (same for A, B and C)
    parameter int ADDR_WIDTH = $clog2(DEPTH) // 13 bits for MT = 32, AS = 8
) (
    input CLK, nRST,
    input logic [5:0] tiles_m, tiles_n, tiles_q,
    input logic exit_flag, start, 
    output logic [ADDR_WIDTH - 1: 0] addr_a, addr_b, addr_c,
    output logic entry_flag, wdone, writer_wren, addr_in_valid
);

    // FEEDER MODULE
    feeder_controller #(
        .AS        (AS),
        .MT        (MT),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
     ) feeder_controller (
        .CLK          (CLK),
        .nRST         (nRST),
        .start        (start),
        .tiles_m      (tiles_m),
        .tiles_n      (tiles_n),
        .tiles_q      (tiles_q),
        .addr_a       (addr_a),
        .addr_b       (addr_b),
        .entry_flag   (entry_flag),
        .addr_in_valid(addr_in_valid)
    );

    // WRITER MODULE
    writer_controller #(
        .AS        (AS),
        .MT        (MT),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
     ) writer_controller (
        .CLK        (CLK),
        .nRST       (nRST),
        .exit_flag  (exit_flag),
        .tiles_m    (tiles_m),
        .tiles_q    (tiles_q),
        .addr_c     (addr_c),
        .wdone      (wdone),
        .writer_wren(writer_wren)
    );
    
endmodule
