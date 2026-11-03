module compute_feeder #(
    parameter AS  = 8 // ARRAY_SIZE, cells per side = tile width. TODO: make power of two for things to work smoothly
) (
    input logic CLK, nRST, start, 
    input logic [7: 0] tiles_m, tiles_n, tiles_q, // tiles of m, n, and q in that order
    output logic [15 + $clog2(AS): 0] addr_A, addr_B, // addresses to read from matrices A and B
    output logic entry_flag
);
    localparam T = 0; // counts rows/columns in a tile
    localparam K = 1; // counts tile multiplications for a given output tile
    localparam J = 2; // counts columns for output tiles
    localparam I = 3; // counts rows for output tiles

    // counter signals
    logic [7:0] count [4];
    logic [7:0] rollover_val [4];
    logic [3:0] rollover_flag; // packed: one 4-bit vector for the AND reduction
    logic clear;
    logic enable [4];

    // fsm signals
    logic fsm_enable;
    logic fsm_clear;

    // FEEDER FSM
    feeder_fsm feeder_fsm (
        .CLK          (CLK),
        .nRST         (nRST),
        .start        (start),
        .rollover_flag(rollover_flag),
        .clear        (fsm_clear),
        .enable       (fsm_enable)
    );

    // COUNTERS 
    for (genvar i = 0; i < 4; i++) begin : counters
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
    
    // COUNTER CONTROL BLOCK
    always_comb begin : counter_control_logic
        clear = fsm_clear;
        enable[T] = fsm_enable;
        enable[K] = rollover_flag[T];
        enable[J] = &rollover_flag[K:T];
        enable[I] = &rollover_flag[J:T];

        rollover_val[T] = AS - 1;
        rollover_val[K] = ((tiles_n) > 2 ? tiles_n : 2) - 1; // TODO: TEST IF THIS IS NECESSARY
        // rollover_val[K] = tiles_n - 1; // TODO: SEE IF THIS WORKS
        rollover_val[J] = tiles_q - 1;
        rollover_val[I] = tiles_m - 1;
    end

    // COMPUTE ADDRESS FOR A
    compute_addr #(
        .AS(AS)
     ) compute_addr_A (
        .CLK             (CLK),
        .nRST            (nRST),
        .clear           (&rollover_flag || fsm_clear),
        .inner_tile_count(count[K]),
        .in_tile_count   (count[T]),
        .tiles           (tiles_n),
        .grow_en         (&rollover_flag[J:T]),
        .addr            (addr_A)
    );

    // COMPUTE ADDRESS FOR B
    compute_addr #(
        .AS(AS)
     ) compute_addr_B (
        .CLK             (CLK),
        .nRST            (nRST),
        .clear           (&rollover_flag[J:T] || fsm_clear),
        .inner_tile_count(count[K]),
        .in_tile_count   (count[T]),
        .tiles           (tiles_n),
        .grow_en         (&rollover_flag[K:T]),
        .addr            (addr_B)
    );

    // EXIT FLAG LOGIC
    assign entry_flag = !(|count[K] || |count[T]) && fsm_enable;

endmodule
