module top_module_fsm (
    input logic CLK, nRST,
    input logic start,
    input logic uart_done_load, uart_done_readback,
    input logic compute_done,
    output logic uart_access_mem, 
    output logic controller_access_mem, 
    output logic start_compute,
    output logic start_uart_load, start_uart_readback,
    output logic done
);

    // controller code
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        COMPUTE,
        READBACK,
        DONE
    } state_t;
    state_t state, next_state;

    always_comb begin : next_state_logic
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = uart_done_load ? COMPUTE : LOAD;
            COMPUTE: next_state = compute_done ? READBACK : COMPUTE;
            READBACK: next_state = uart_done_readback ? DONE : READBACK;
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

    // NOTE: clear = !en, but they are used for separate things so this is clearer for what each does
    always_comb begin : output_logic 
        case (state) 
            IDLE: begin
                uart_access_mem = 0;
                controller_access_mem = 0;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                done = 0;
            end
            LOAD: begin
                uart_access_mem = 1;
                controller_access_mem = 0;
                start_uart_load = 1;
                start_compute = 0;
                start_uart_readback = 0;
                done = 0;
            end
            COMPUTE: begin
                uart_access_mem = 0;
                controller_access_mem = 1;
                start_uart_load = 0;
                start_compute = 1;
                start_uart_readback = 0;
                done = 0;
            end
            READBACK: begin
                uart_access_mem = 1;
                controller_access_mem = 0;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 1;
                done = 0;
            end
            DONE: begin
                uart_access_mem = 0;
                controller_access_mem = 0;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                done = 1;
            end
            default: begin // same as idle
                uart_access_mem = 0;
                controller_access_mem = 0;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                done = 0;
            end
        endcase
    end
        
endmodule
