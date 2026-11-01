module compute_writer #(
    parameter AS  = 4, // ARRAY_SIZE, cells per side = tile width. TODO: make power of two for things to work smoothly
    parameter MAX_TILES = 3 // This is passed in by the tiling controller. The tiling controller will share the calculation with feeder
) (
    input logic CLK, nRST, exit_flag,
    input logic [MAX_TILES - 1: 0] tiles_m, tiles_q // tiles of m and q in that order
);

    // localparams
    localparam ROW_W = $clog2(AS); // width of row counter in bits
    localparam IJ_W = (MAX_TILES > 1) ? $clog2(MAX_TILES) : 1; // width of i and j counter in bits
    localparam int WIDTHS [3] = '{ROW_W, IJ_W, IJ_W}; // for generate
    localparam int MAX_W = (ROW_W > IJ_W) ? ROW_W : IJ_W;

    localparam ROW = 0; // counts current row copying
    localparam J = 1; // counts columns for output tiles
    localparam I = 2; // counts rows for output tiles

    // controller code
    typedef enum logic [1:0] {
        IDLE,
        WAIT,
        COPY_ROW,
        DONE
    } state_t;
    state_t state, next_state;

    // counter signals
    logic [MAX_W-1:0] count [3];
    logic [MAX_W-1:0] rollover_val [3];
    logic [2:0] rollover_flag; // packed: one 3-bit vector for the AND reduction
    logic clear;
    logic enable [3];

    for (genvar g = 0; g < 3; g++) begin : counters
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
    
        assign count[g] = cnt; // zero-extends to MAX_W, top bits = 0 instead of x
    end
    
    // enables for the counters
    always_comb begin : counter_control_logic
        clear = (state == IDLE); // clear counters on IDLE
        enable[ROW] = (state == COPY_ROW); // copies a new row every cycle.
        enable[J] = &rollover_flag[ROW] && enable[ROW]; // AND reduction
        enable[I] = &rollover_flag[J:ROW] && enable[ROW]; // AND reduction
        rollover_val[ROW] = AS - 1;
        rollover_val[J] = tiles_q - 1;
        rollover_val[I] = tiles_m - 1;
    end

    always_comb begin : next_state_logic
        case (state)
            IDLE: next_state = exit_flag ? WAIT : IDLE;
            WAIT: next_state = exit_flag ? COPY_ROW : WAIT;
            COPY_ROW:
                if (&rollover_flag) begin // All tiles are done
                next_state = DONE;
                end else if (&rollover_flag[J:ROW]) begin // waiting for the next tile. This means that this tile is done
                    next_state = WAIT;
                end else begin // next row
                    next_state = COPY_ROW;
                end
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
