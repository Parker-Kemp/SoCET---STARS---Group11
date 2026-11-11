module top_module #(
    parameter int AS = 8, // array side length
    parameter int MT = 32 // max tiles per matrix side (32 * 8 = 256)
) (
    input logic uart_stuff, // TODO: Parker hook up to UART.
    input logic CLK, nRST, start_async,
    output logic done
);
    localparam int WORD_WIDTH_AB = 8 * AS;
    localparam int WORD_WIDTH_C = 32 * AS;
    localparam int DEPTH = MT * MT * AS; // words per block (same for A, B and C)
    localparam int ADDR_WIDTH = $clog2(DEPTH); // 13 bits for MT = 32, AS = 8

    logic start; // synced start

    // signals for Block A
    logic [ADDR_WIDTH-1:0] addr_a;
    logic [WORD_WIDTH_AB-1:0] data_in_a;
    logic wren_a;
    logic [WORD_WIDTH_AB-1:0] data_out_a;

    // signals for Block B
    logic [ADDR_WIDTH-1:0] addr_b;
    logic [WORD_WIDTH_AB-1:0] data_in_b;
    logic wren_b;
    logic [WORD_WIDTH_AB-1:0] data_out_b;

    // signals for Block C
    logic [ADDR_WIDTH-1:0] addr_c;
    logic [WORD_WIDTH_C-1:0] data_in_c;
    logic wren_c;
    logic [WORD_WIDTH_C-1:0] data_out_c;

    // Addr control signals (who gets control)
    logic uart_access_mem;
    logic controller_access_mem;

    // tile signals
    logic [5:0] tiles_m;
    logic [5:0] tiles_n;
    logic [5:0] tiles_q;

    // TODO: UART SIGNALS (PARKER) - Hook up to UART module
    // tile signals out of UART
    logic [5:0] tiles_m_uart; // 6 bits because MT = 32 and we need to hold 32 itself
    logic [5:0] tiles_n_uart;
    logic [5:0] tiles_q_uart;
    logic [ADDR_WIDTH-1:0] uart_addr_a;
    logic [ADDR_WIDTH-1:0] uart_addr_b;
    logic [ADDR_WIDTH-1:0] uart_addr_c;
    logic [WORD_WIDTH_AB-1:0] uart_data_a;
    logic [WORD_WIDTH_AB-1:0] uart_data_b; 
    logic [WORD_WIDTH_C-1:0] uart_data_c; 
    logic uart_wren_a; // TODO: write enable for a and b for memory
    logic uart_wren_b;
    logic valid_tiles; // TODO: HIGH if tiles_uart are valid
    logic start_uart_load; // TODO: each stage of uart gets both a start input and done output
    logic start_uart_readback;
    logic uart_done_load;
    logic uart_done_readback;

    // TODO: systolic array signals (Barry) - Hook up to systolic array module
    logic data_in_valid; // HIGH if addr is valid. One cycle delay to match memory latency
    logic [WORD_WIDTH_AB-1:0] data_in_a_array;
    logic [WORD_WIDTH_AB-1:0] data_in_b_array;
    logic [WORD_WIDTH_C-1:0] data_out_array; 

    // addr_controller signals
    logic [ADDR_WIDTH-1:0] controller_addr_a;
    logic [ADDR_WIDTH-1:0] controller_addr_b;
    logic [ADDR_WIDTH-1:0] controller_addr_c;
    logic addr_in_valid;
    logic writer_wren; // enables writing into C
    logic exit_flag; // TODO: Hook up to SYSTOLIC ARRAY. SHARED WITH SYSTOLIC ARRAY
    logic entry_flag; // TODO: Hook up to SYSTOLIC ARRAY. SHARED WITH SYSTOLIC ARRAY
    logic start_compute;
    logic compute_done;

    // SYNCHRONIZER FOR START SIGNAL
    two_ff_synchronizer start_synchronizer (
        .CLK     (CLK),
        .async_in(start_async),
        .sync_out(start)
    );

    // RAM
    multi_block_ram #(
        .AS           (AS),
        .MT           (MT)
     ) multi_block_ram (
        .CLK       (CLK),
        .addr_a    (addr_a),
        .data_in_a (data_in_a),
        .wren_a    (wren_a),
        .data_out_a(data_out_a),
        .addr_b    (addr_b),
        .data_in_b (data_in_b),
        .wren_b    (wren_b),
        .data_out_b(data_out_b),
        .addr_c    (addr_c),
        .data_in_c (data_in_c),
        .wren_c    (wren_c),
        .data_out_c(data_out_c)
    
    );

    // FSM
    top_module_fsm top_module_fsm (
        .CLK                  (CLK),
        .nRST                 (nRST),
        .start                (start),
        .uart_done_load       (uart_done_load),
        .uart_done_readback   (uart_done_readback),
        .compute_done         (compute_done),
        .uart_access_mem      (uart_access_mem),
        .controller_access_mem(controller_access_mem),
        .start_compute        (start_compute),
        .start_uart_load      (start_uart_load),
        .start_uart_readback  (start_uart_readback),
        .done                 (done)
    );

    // MEMORY ACCESS CONTROLL
    // TODO: VERY MESSY SO NEEDS FIXING
    always_comb begin : mem_access_control
        if (uart_access_mem) begin
            addr_a = uart_addr_a;
            addr_b = uart_addr_b;
            addr_c = uart_addr_c;

            wren_a = uart_wren_a;
            wren_b = uart_wren_b;
            wren_c = 0;

            data_in_a = uart_data_a;
            data_in_b = uart_data_a;
            uart_data_c = data_out_c;

        end else if (controller_access_mem) begin
            addr_a = controller_addr_a;
            addr_b = controller_addr_b;
            addr_c = controller_addr_c;

            wren_a = 0;
            wren_b = 0;
            wren_c = writer_wren;
            
            data_in_a_array = data_out_a;
            data_in_b_array = data_out_b;
            // TODO: data_out_c = data_out_array;

        end else begin
            addr_a = 0;
            addr_b = 0;
            addr_c = 0;

            wren_a = 0;
            wren_b = 0;
            wren_c = 0;

            data_in_a = 0;
            data_in_b = 0;
            data_in_c = 0;
        end
    end

    // TILE REGISTERS
    always_ff @(posedge CLK, negedge nRST) begin : tiles_registers
        if (!nRST) begin
            tiles_m <= 0;
            tiles_n <= 0;
            tiles_q <= 0;
        end else if (valid_tiles) begin // storing in register if valid tiles come out of uart.
            tiles_m <= tiles_m_uart;
            tiles_n <= tiles_n_uart;
            tiles_q <= tiles_q_uart;
        end
    end

    // Delays the signals one cycle so that it will align with memory
    always_ff @(posedge CLK, negedge nRST) begin : addr_data_sync
        if (!nRST) begin
            data_in_valid <= 0;
        end else begin
            data_in_valid <= addr_in_valid;
        end
    end

    // ADDRESS CONTROLLER
    addr_controller #(
        .AS        (AS),
        .MT        (MT),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
     ) addr_controller (
        .CLK          (CLK),
        .nRST         (nRST),
        .tiles_m      (tiles_m),
        .tiles_n      (tiles_n),
        .tiles_q      (tiles_q),
        .exit_flag    (exit_flag),
        .start        (start_compute),
        .addr_a       (controller_addr_a),
        .addr_b       (controller_addr_b),
        .addr_c       (controller_addr_c),
        .entry_flag   (entry_flag),
        .wdone        (compute_done),
        .writer_wren  (writer_wren),
        .addr_in_valid(addr_in_valid)
    );

endmodule
