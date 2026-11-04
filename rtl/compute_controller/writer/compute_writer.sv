module compute_writer #(
    parameter AS  = 8 // ARRAY_SIZE
) (
    input logic CLK, nRST, exit_flag,
    input logic [7:0] tiles_m, tiles_q,
    output logic [15 + $clog2(AS):0] addr_C,
    output logic wdone
);

    localparam ROW = 0; // counts current row copying
    localparam J = 1; // counts columns for output tiles
    localparam I = 2; // counts rows for output tiles

    // counter signals
    logic [7:0] count [3];
    logic [7:0] rollover_val [3];
    logic [2:0] rollover_flag; // packed: one 3-bit vector for the AND reduction
    logic clear;
    logic enable [3];

    logic fsm_enable;
    logic fsm_clear;

    // WRITER FSM
    writer_fsm writer_fsm (
        .CLK          (CLK),
        .nRST         (nRST),
        .exit_flag    (exit_flag),
        .rollover_flag(rollover_flag),
        .clear        (fsm_clear),
        .enable       (fsm_enable),
        .wdone        (wdone)
    );

    // COUNTERS 
    for (genvar i = 0; i < 3; i++) begin : counters
        warp_counter #(.NUM_CNT_BITS(8)) counter (
            .clk          (CLK),
            .n_rst        (nRST),
            .clear        (clear), // one shared clear
            .count_enable (enable[i]),
            .rollover_val (rollover_val[i]),
            .count_out    (count[i]),
            .rollover_flag(rollover_flag[i])
        );
    end
    
    // COUNTER CONTROL
    always_comb begin : counter_control_logic
        clear = fsm_clear;
        enable[ROW] = fsm_enable; // copies a new row every cycle.
        enable[J] = &rollover_flag[ROW];
        enable[I] = &rollover_flag[J:ROW];
        rollover_val[ROW] = AS - 1;
        rollover_val[J] = tiles_q - 1;
        rollover_val[I] = tiles_m - 1;
    end 

    // COMPUTE ADDRESS FOR C
    compute_addr #(
        .AS(AS)
     ) compute_addr_C (
        .CLK             (CLK),
        .nRST            (nRST),
        .clear           (fsm_clear),
        .inner_tile_count(count[J]),
        .in_tile_count   (count[ROW]),
        .tiles           (tiles_q),
        .grow_en         (&rollover_flag[J:ROW]),
        .addr            (addr_C)
    );

endmodule
