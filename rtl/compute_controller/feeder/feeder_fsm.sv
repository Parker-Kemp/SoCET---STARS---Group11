module feeder_fsm (
    input logic CLK, nRST,
    input logic start, input logic [3:0]rollover_flag,
    output logic clear, enable
);
    localparam T = 0; // counts rows/columns in a tile
    localparam K = 1; // counts tile multiplications for a given output tile

    // controller code
    typedef enum logic [1:0] {
        IDLE,
        FEED,
        FLUSH,
        DONE
    } state_t;
    state_t state, next_state;

    always_comb begin : next_state_logic
        case (state)
            IDLE: next_state = start ? FEED : IDLE;
            FEED: next_state = (&rollover_flag) ? FLUSH : FEED;
            FLUSH: next_state = &rollover_flag[K:T] ? DONE : FLUSH;
            DONE: next_state = IDLE; // DONE once done FEEDING (not when controller is done)
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge CLK, negedge nRST) begin : state_register
        if (nRST == 0) begin
            state <= IDLE;	
        end else begin
            state <= next_state;
        end
    end  

    // NOTE: clear = !en, but they are used for separate things so this is clearer for what each does
    always_comb begin : output_logic 
        case (state) 
            IDLE: begin
                clear = 1;
                enable = 0;
            end
            FEED: begin
                clear = 0;
                enable = 1;
            end
            FLUSH: begin
                clear = 0;
                enable = 1;
            end
            DONE: begin
                clear = 1;
                enable = 0;
            end
            default: begin
                clear = 1;
                enable = 0;
            end
        endcase
    end
        
endmodule
