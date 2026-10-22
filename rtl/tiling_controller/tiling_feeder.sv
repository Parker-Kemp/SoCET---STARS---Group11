module tiling_feeder #(
    parameter AS  = 8, // ARRAY_SIZE, cells per side = tile width. TODO: make power of two for things to work smoothly
    parameter MAX = 20 // largest supported matrix dimension (TODO: placeholder until we know the board's memory
) (
    // REVIEW: p_mat2 might not be needed so remove if so.
    input logic CLK, nRST, start, last_cell_flag,
    input logic [MAX - 1: 0] m_mat1, n_mat1, p_mat2, q_mat2 // m, n, p, q in that order
);

    // localparams
    localparam MAX_TILES = (MAX + AS - 1) / AS; // max value of tiles based off max size
    localparam K_MAX     = (MAX_TILES < 2) ? 2 : MAX_TILES; // max value of K counter
    localparam AS_POWER  = $clog2(AS);

    localparam T_W = $clog2(AS); // width of t counter in bits
    localparam K_W = $clog2(K_MAX); // width of k counter in bits
    localparam IJ_W = (MAX_TILES > 1) ? $clog2(MAX_TILES) : 1; // width of i and j counter in bits
    localparam int WIDTHS [4] = '{T_W, K_W, IJ_W, IJ_W};
    localparam int MAX_W = (T_W > K_W)
                     ? ((T_W > IJ_W) ? T_W : IJ_W)
                     : ((K_W > IJ_W) ? K_W : IJ_W);

    localparam T = 0;
    localparam K = 1;
    localparam J = 2;
    localparam I = 3;

    // calculates tiles
    let tiles(length) = (length >> AS_POWER) + |length[AS_POWER-1:0];

    // controller code
    typedef enum logic [1:0] {
        IDLE,
        FEED,
        FLUSH,
        DONE
    } state_t;
    state_t state, next_state;

    // counter signals
    logic [MAX_W-1:0] count [4];
    logic [MAX_W-1:0] rollover_val [4];
    logic [3:0] rollover_flag; // packed: one 4-bit vector for the AND reduction
    logic clear;
    logic enable [4];

    for (genvar g = 0; g < 4; g++) begin : counters
        logic [WIDTHS[g]-1:0] cnt;   // exact width for this counter
    
        warp_counter #(.NUM_CNT_BITS(WIDTHS[g])) counter (
            .clk(CLK),
            .n_rst(nRST),
            .clear(clear), // one shared clear
            .count_enable(enable[g]),
            .rollover_val(rollover_val[g][WIDTHS[g]-1:0]), // reading a slice is fine
            .count_out(cnt),
            .rollover_flag(rollover_flag[g])
        );
    
        assign count[g] = cnt;   // zero-extends to MAX_W, top bits = 0 instead of x
    end
    
    // enables for the counters
    always_comb begin : counter_control_logic
        clear = (state == IDLE); // clear counters on IDLE
        enable[T] = (state == FEED) || (state == FLUSH); // always enables T in those states
        enable[K] = rollover_flag[T] && enable[T]; // enable[T] to test state
        enable[J] = &rollover_flag[K:T] && enable[T]; // AND reduction
        enable[I] = &rollover_flag[J:T] && enable[T]; // AND reduction
        rollover_val[T] = AS - 1;
        rollover_val[K] = ((tiles(n_mat1)) > 2 ? tiles(n_mat1) : 2) - 1;
        rollover_val[J] = tiles(q_mat2) - 1;
        rollover_val[I] = tiles(m_mat1) - 1;
    end

    always_comb begin : next_state_logic
        case (state)
            IDLE: next_state = start ? FEED : IDLE;
            FEED: next_state = (&rollover_flag) ? FLUSH : FEED;
            FLUSH: next_state = last_cell_flag ? DONE : FLUSH;
            DONE: next_state = IDLE;
            default: next_state = state;
        endcase
    end

    always_ff @(posedge CLK, negedge nRST) begin : state_register
        if (nRST == 0) begin
            state <= IDLE;	
        end else begin
            state <= next_state;
        end
    end  

    // TODO: OUTPUT LOGIC

endmodule
