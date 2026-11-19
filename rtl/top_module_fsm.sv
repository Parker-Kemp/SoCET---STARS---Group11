module top_module_fsm     
    import mem_pkg::*;
(
    input logic CLK, nRST,
    input logic start,
    input logic uart_done_load, uart_done_readback,
    input logic compute_done,
    output mem_owner_t mem_owner,
    output logic start_compute,
    output logic start_uart_load, start_uart_readback,
    output logic done, clkc_enable, clkc_clear
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
                mem_owner = MEM_NONE;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                clkc_enable = 0;
                clkc_clear = 1;
                done = 0;
            end
            LOAD: begin
                mem_owner = MEM_UART;
                start_uart_load = 1;
                start_compute = 0;
                start_uart_readback = 0;
                clkc_enable = 0;
                clkc_clear = 0;
                done = 0;
            end
            COMPUTE: begin
                mem_owner = MEM_COMPUTE;
                start_uart_load = 0;
                start_compute = 1;
                start_uart_readback = 0;
                clkc_enable = 1;
                clkc_clear = 0;
                done = 0;
            end
            READBACK: begin
                mem_owner = MEM_UART;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 1;
                clkc_enable = 0;
                clkc_clear = 0;
                done = 0;
            end
            DONE: begin
                mem_owner = MEM_NONE;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                clkc_enable = 0;
                clkc_clear = 0;
                done = 1;
            end
            default: begin 
                mem_owner = MEM_NONE;
                start_uart_load = 0;
                start_compute = 0;
                start_uart_readback = 0;
                clkc_enable = 0;
                clkc_clear = 1;
                done = 0;
            end
        endcase
    end
        
endmodule
