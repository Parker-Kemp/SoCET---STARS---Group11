// This module just merges the feeder and writer.
module compute_controller #(
    parameter AS = 8
) (
    input CLK, nRST,
    input logic [7:0] tiles_m, tiles_n, tiles_q,
    input logic exit_flag, start,
    output logic [15 + $clog2(AS): 0] addr_A, addr_B, addr_C,
    output logic entry_flag, wdone
);

    // FEEDER MODULE
    compute_feeder #(
        .AS(AS)
     ) compute_feeder (
        .CLK       (CLK),
        .nRST      (nRST),
        .start     (start),
        .tiles_m   (tiles_m),
        .tiles_n   (tiles_n),
        .tiles_q   (tiles_q),
        .addr_A    (addr_A),
        .addr_B    (addr_B),
        .entry_flag(entry_flag)
    );

    // WRITER MODULE
    compute_writer #(
        .AS(AS)
     ) compute_writer (
        .CLK      (CLK),
        .nRST     (nRST),
        .exit_flag(exit_flag),
        .tiles_m  (tiles_m),
        .tiles_q  (tiles_q),
        .addr_C   (addr_C),
        .wdone    (wdone)
    );
    
endmodule
