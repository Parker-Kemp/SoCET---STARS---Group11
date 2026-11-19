module top_module 
    import mem_pkg::*;
#(
    parameter int AS = 8, // array side length
    parameter int MT = 32 // max tiles per matrix side (32 * 8 = 256)
) (
    input logic uart_stuff, // TODO: Parker hook up to UART as necessary
    input logic CLK, nRST, start_async,
    output logic fsm_done
);
    localparam DATA_W = 8;
    localparam ACC_W = 32;
    localparam int WORD_WIDTH_AB = DATA_W * AS;
    localparam int WORD_WIDTH_C = ACC_W * AS;
    localparam int DEPTH = MT * MT * AS; // words per block (same for A, B and C)
    localparam int ADDR_WIDTH = $clog2(DEPTH); // 13 bits for MT = 32, AS = 8
    localparam int TILE_W = $clog2(MT+1); // 6 when MT = 32

    logic start; // synced start

    // signals for Block A
    logic [ADDR_WIDTH-1:0] mem_addr_a;
    logic [WORD_WIDTH_AB-1:0] mem_din_a;
    logic mem_wren_a;
    logic [WORD_WIDTH_AB-1:0] mem_dout_a;

    // signals for Block B
    logic [ADDR_WIDTH-1:0] mem_addr_b;
    logic [WORD_WIDTH_AB-1:0] mem_din_b;
    logic mem_wren_b;
    logic [WORD_WIDTH_AB-1:0] mem_dout_b;

    // signals for Block C
    logic [ADDR_WIDTH-1:0] mem_addr_c;
    logic [WORD_WIDTH_C-1:0] mem_din_c;
    logic mem_wren_c;
    logic [WORD_WIDTH_C-1:0] mem_dout_c;

    // tile signals
    logic [TILE_W-1:0] tiles_m;
    logic [TILE_W-1:0] tiles_n;
    logic [TILE_W-1:0] tiles_q;

    // FSM signals (fsm)
    logic fsm_start_compute;
    logic fsm_uc_memen; // fsm enables uart to access memory (mem-enable: memen): 1 - uart access | 0 - compute acess
    logic fsm_start_uc_load; // TODO: each stage of uart gets both a start input and done output
    logic fsm_start_uc_rb; // TODO: THIS CONNECTS TO UART
    logic fsm_clkc_enable;
    logic fsm_clkc_clear;
    mem_owner_t fsm_mem_owner;

    // TODO: UART SIGNALS (uc) (PARKER) - fix up the signals here because its a mess
    // tile signals out of UART
    logic [TILE_W-1:0] uc_tiles_m; // 6 bits because MT = 32 and we need to hold 32 itself
    logic [TILE_W-1:0] uc_tiles_n;
    logic [TILE_W-1:0] uc_tiles_q;
    logic [ADDR_WIDTH-1:0] uc_addr_a;
    logic [ADDR_WIDTH-1:0] uc_addr_b;
    logic [ADDR_WIDTH-1:0] uc_addr_c;
    logic signed [WORD_WIDTH_AB-1:0] uc_data_a;
    logic signed [WORD_WIDTH_AB-1:0] uc_data_b; 
    logic signed [WORD_WIDTH_C-1:0] uc_data_c; 
    logic uc_wren_a; // TODO: write enable for a and b for memory
    logic uc_wren_b;
    logic uc_valid_tiles; // TODO: HIGH if tiles_uart are valid
    logic uc_done_load; // uart is done load
    logic uc_done_rb; // uart is done readback

    // TODO: systolic array signals (sa)
    logic signed [DATA_W-1:0] sa_a_row_in [AS];
    logic signed [DATA_W-1:0] sa_b_col_in [AS];
    logic signed [ACC_W-1:0]  sa_c_out [AS][AS];
    logic sa_exit_flag; // SHARED WITH CONTROLLER

    // addr_controller signals (ac)
    logic [ADDR_WIDTH-1:0] ac_addr_a;
    logic [ADDR_WIDTH-1:0] ac_addr_b;
    logic [ADDR_WIDTH-1:0] ac_addr_c;
    logic ac_wren; // enables writing into mem block C
    logic ac_entry_flag;
    logic ac_entry_flag_d; // SHARED WITH SYSTOLIC ARRAY
    logic ac_compute_done;
    logic [$clog2(AS)-1:0] ac_row_cnt;
    logic [7:0] ac_k_cnt;
    logic [7:0] ac_k_cnt_d;

    // CLK counter signals
    logic [15:0] clkc_count;
    logic clkc_rollover_flag; // NOT USED

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
    ) ram (
        .CLK       (CLK),
        .addr_a    (mem_addr_a),
        .data_in_a (mem_din_a),
        .wren_a    (mem_wren_a),
        .data_out_a(mem_dout_a),
        .addr_b    (mem_addr_b),
        .data_in_b (mem_din_b),
        .wren_b    (mem_wren_b),
        .data_out_b(mem_dout_b),
        .addr_c    (mem_addr_c),
        .data_in_c (mem_din_c),
        .wren_c    (mem_wren_c),
        .data_out_c(mem_dout_c)
    
    );

    // TOP MODULE FSM
    top_module_fsm top_module_fsm (
        .CLK                (CLK),
        .nRST               (nRST),
        .start              (start),
        .uart_done_load     (uc_done_load),
        .uart_done_readback (uc_done_rb),
        .compute_done       (ac_compute_done),
        .mem_owner          (fsm_mem_owner),
        .start_compute      (fsm_start_compute),
        .start_uart_load    (fsm_start_uc_load),
        .start_uart_readback(fsm_start_uc_rb),
        .done               (fsm_done),
        .clkc_enable        (fsm_clkc_enable),
        .clkc_clear         (fsm_clkc_clear)
    );

    // MEMORY ACCESS CONTROLL
    // TODO: VERY MESSY SO NEEDS FIXING
    always_comb begin : mem_access_control
        // defaults: everything gets a value no matter what state its in
        mem_addr_a = '0;
        mem_addr_b = '0;
        mem_addr_c = '0;
        mem_wren_a = 1'b0;
        mem_wren_b = 1'b0;
        mem_wren_c = 1'b0;
        mem_din_a = '0;
        mem_din_b = '0;
        mem_din_c = '0;
        uc_data_c = '0;
        sa_a_row_in = '{default: '0}; // unpacked array, so cant use '0 here
        sa_b_col_in = '{default: '0};

        case (fsm_mem_owner)
            MEM_NONE: begin
                mem_wren_a = 0;
                mem_wren_b = 0;
                mem_wren_c = 0;
            end
            MEM_COMPUTE: begin
                mem_addr_a = ac_addr_a;
                mem_addr_b = ac_addr_b;
                mem_addr_c = ac_addr_c;

                mem_wren_a = 0;
                mem_wren_b = 0;
                mem_wren_c = ac_wren;

                if (ac_k_cnt_d >= tiles_n) begin // ONLY IN THE EDGE CASE FOR tiles_n == 1
                    for (int i = 0; i < AS; i++) begin
                        sa_a_row_in[i] = '0;
                        sa_b_col_in[i] = '0;
                        mem_din_c[i*ACC_W +: ACC_W] = $unsigned(sa_c_out[ac_row_cnt][i]);
                    end
                end else begin
                    for (int i = 0; i < AS; i++) begin
                        sa_a_row_in[i] = $signed(mem_dout_a[i*DATA_W +: DATA_W]);
                        sa_b_col_in[i] = $signed(mem_dout_b[i*DATA_W +: DATA_W]);
                        mem_din_c[i*ACC_W +: ACC_W] = $unsigned(sa_c_out[ac_row_cnt][i]);
                    end
                end
            end
            MEM_UART: begin
                mem_wren_a = uc_wren_a;
                mem_wren_b = uc_wren_b;
                mem_wren_c = 0;

                mem_addr_a = uc_addr_a;
                mem_addr_b = uc_addr_b;
                mem_addr_c = uc_addr_c;

                mem_din_a = $unsigned(uc_data_a);
                mem_din_b = $unsigned(uc_data_b);
                uc_data_c = $signed(mem_dout_c);
            end
            default: begin end
        endcase
    end

    // TILE REGISTERS
    always_ff @(posedge CLK, negedge nRST) begin : tiles_registers
        if (!nRST) begin
            tiles_m <= 0;
            tiles_n <= 0;
            tiles_q <= 0;
        end else if (uc_valid_tiles) begin // storing in register if valid_tiles come out of uart.
            tiles_m <= uc_tiles_m;
            tiles_n <= uc_tiles_n;
            tiles_q <= uc_tiles_q;
        end
    end

    // ADDRESS CONTROLLER
    addr_controller #(
        .AS        (AS),
        .MT        (MT),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_W    (TILE_W)
     ) addr_controller (
        .CLK        (CLK),
        .nRST       (nRST),
        .tiles_m    (tiles_m),
        .tiles_n    (tiles_n),
        .tiles_q    (tiles_q),
        .exit_flag  (sa_exit_flag),
        .start      (fsm_start_compute),
        .addr_a     (ac_addr_a),
        .addr_b     (ac_addr_b),
        .addr_c     (ac_addr_c),
        .entry_flag (ac_entry_flag),
        .wdone      (ac_compute_done),
        .writer_wren(ac_wren),
        .row_cnt    (ac_row_cnt), // 3 BITS IS ENOUGH BECAUSE ROW SHOULD ONLY COUNT FROM 0 to AS - 1
        .k_cnt      (ac_k_cnt)
    );

    shift_reg #(
        .WIDTH(1),
        .DEPTH(1)
    ) shift_entry_flag (
        .CLK     (CLK),
        .nRST    (nRST),
        .data_in (ac_entry_flag),
        .data_out(ac_entry_flag_d)
    );

    shift_reg #(
        .WIDTH(1),
        .DEPTH(1)
    ) shift_k_cnt (
        .CLK     (CLK),
        .nRST    (nRST),
        .data_in (ac_k_cnt),
        .data_out(ac_k_cnt_d)
    );

    // SYSTOLIC ARRAY
    systolic_array #(
        .AS    (AS),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
     ) systolic_array (
        .CLK      (CLK),
        .nRST     (nRST),
        .flag_in  (ac_entry_flag_d),
        .a_row_in (sa_a_row_in),
        .b_col_in (sa_b_col_in),
        .c_out    (sa_c_out),
        .exit_flag(sa_exit_flag)
    );

    // CLK COUNTER USED FOR BENCHMARKS
    warp_counter #(
        .NUM_CNT_BITS(16) // 2 bytes for UART
    ) clk_cycle_counter (
        .clk          (CLK),
        .n_rst        (nRST),
        .clear        (fsm_clkc_clear),
        .count_enable (fsm_clkc_enable),
        .rollover_val (clkc_count + 2), // shouldn't roll over
        .count_out    (clkc_count),
        .rollover_flag(clkc_rollover_flag)
    );

endmodule
