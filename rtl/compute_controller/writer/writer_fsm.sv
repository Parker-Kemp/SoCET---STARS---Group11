module writer_fsm (
    input logic CLK, nRST,
    input logic exit_flag, 
    input logic [2:0]rollover_flag,
    output logic clear, enable, wdone
);
    localparam ROW = 0; // counts rows/columns in a tile
    localparam J = 1; // counts columns for output tiles

    // controller code
    typedef enum logic [1:0] {
        IDLE,
        WAIT,
        ROW_COPY,
        DONE
    } state_t;
    state_t state, next_state;

    always_comb begin : next_state_logic
        case (state)
            IDLE: next_state = exit_flag ? WAIT : IDLE;
            WAIT: next_state = exit_flag ? ROW_COPY : WAIT;
            ROW_COPY: begin
                if (&rollover_flag) begin
                    next_state = DONE;
                end else if (&rollover_flag[J:ROW]) begin
                    next_state = WAIT;
                end else begin
                    next_state = ROW_COPY;
                end
            end
            DONE: next_state = IDLE;
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

    always_comb begin : output_logic 
        case (state) 
            IDLE: begin
                clear = 1;
                enable = 0;
                wdone = 0;
            end
            WAIT: begin
                clear = 0;
                enable = 0;
                wdone = 0;
            end
            ROW_COPY: begin
                clear = 0;
                enable = 1;
                wdone = 0;
            end
            DONE: begin
                clear = 1;
                enable = 0;
                wdone = 1;
            end
            default: begin
                clear = 1;
                enable = 0;
                wdone = 0;
            end
        endcase
    end
        
endmodule
