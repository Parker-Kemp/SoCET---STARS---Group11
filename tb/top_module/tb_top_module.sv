module tb_top_module;

    localparam AS = 8;
    localparam MT = 32; // max tile count
    localparam DATA_W = 8;
    localparam ACC_W = 32;
    localparam NT = 10; // number of tests: 5 edge cases (always minimum of 5) and the rest are random

    logic uart_stuff; // doesn't do anything
    logic CLK, nRST;
    logic start, done;

    initial CLK = 0;
    always #10 CLK = ~CLK;

    top_module #(
        .AS(AS),
        .MT(MT)
     ) DUT (
        .uart_stuff (uart_stuff),
        .CLK        (CLK),
        .nRST       (nRST),
        .start_async(start),
        .fsm_done   (done)
    );

    string run_dir;
    int return_code;

    task automatic make_run_dir();
        string date;
        int folder_dir, run;

        void'($system("date +%Y-%m-%d > .sim_date.txt"));
        folder_dir = $fopen(".sim_date.txt", "r");
        void'($fscanf(folder_dir, "%s", date));
        $fclose(folder_dir);
        void'($system("rm -f .sim_date.txt"));

        run = 1;
        run_dir = $sformatf("results/csv_records/top_module/%s_run%0d", date, run);
        while ($system({"test -d ", run_dir}) == 0) begin
            run++;
            run_dir = $sformatf("results/csv_records/top_module/%s_run%0d", date, run);
        end

        void'($system({"mkdir -p ", run_dir}));
        $display("Saving CSVs to %s", run_dir);
    endtask

    logic signed [DATA_W-1:0] A [NT][AS*MT][AS*MT];
    logic signed [DATA_W-1:0] B [NT][AS*MT][AS*MT];
    logic signed [ACC_W-1:0] C [NT][AS*MT][AS*MT];

    task automatic build_matrices(input int test_num);
        for (int i = 0; i < AS * MT; i++) begin
            for (int j = 0; j < AS * MT; j++) begin
                case (test_num)
                    0: begin
                        A[test_num][i][j] = DATA_W'(i*AS + j + 1);  
                        B[test_num][i][j] = (i == j) ? 1 : 0; 
                    end // B = identity, so C must equal A
                    1: begin 
                        A[test_num][i][j] = 0;
                        B[test_num][i][j] = 0;
                    end // all zeros
                    2: begin 
                        A[test_num][i][j] = 127;
                        B[test_num][i][j] = 127;
                    end // biggest positive
                    3: begin 
                        A[test_num][i][j] = -128;
                        B[test_num][i][j] = -128;
                    end // biggest negative
                    4: begin 
                        A[test_num][i][j] = (((i+j) % 2) == 1) ? 127 : -128;
                        B[test_num][i][j] = (((i+j) % 2) == 1) ? -128 : 127;
                    end // sign mix
                    default: begin 
                        B[test_num][i][j] = DATA_W'($urandom ());
                        A[test_num][i][j] = DATA_W'($urandom());
                    end // randoms
                endcase
            end
        end
    endtask

    // DRIVER side
    int folder_dir_a, folder_dir_b, folder_dir_c;

    task automatic init_mem_a(input int t, input int tiles_m, input int tiles_n);
        logic [DATA_W*AS-1:0] word;
        int tile_index, addr;

        // A(i,k)
        @(posedge CLK);
        for (int fi = 0; fi < tiles_m; fi++) begin // tile row
            for (int fk = 0; fk < tiles_n; fk++) begin // tile column
                tile_index = fi*tiles_n + fk;
                for (int col = 0; col < AS; col++) begin // one word = one column of the tile
                    for (int i = 0; i < AS; i++) begin        // slot i = row i of that column
                        word[i*DATA_W +: DATA_W] = $unsigned(A[t][fi*AS + i][fk*AS + col]);
                    end
                    
                    addr = tile_index*AS + col;
                    DUT.ram.mem_block_a.memory_array[addr] = word;
                end
            end
        end

        for (int r = 0; r < tiles_m*AS; r++) begin
            $fwrite(folder_dir_a, "%0d", t);
            for (int c = 0; c < tiles_n*AS; c++) begin 
                $fwrite(folder_dir_a, ",%0d", A[t][r][c]);
            end
            $fwrite(folder_dir_a, "\n");
        end

        repeat (3) @(posedge CLK);
    
    endtask

    task automatic init_mem_b(input int t, input int tiles_n, input int tiles_q);
        logic [DATA_W*AS-1:0] word;
        int tile_index, addr;

        // B(k,j)
        for (int fk = 0; fk < tiles_n; fk++) begin // tile row
            for (int fj = 0; fj < tiles_q; fj++) begin // tile column
                tile_index = fj*tiles_n + fk;
                for (int row = 0; row < AS; row++) begin // one word = one row of the tile
                    for (int i = 0; i < AS; i++) begin // slot i = column i of that row
                        word[i*DATA_W +: DATA_W] = $unsigned(B[t][fk*AS + row][fj*AS + i]);
                    end

                    addr = tile_index*AS + row;
                    DUT.ram.mem_block_b.memory_array[addr] = word;
                end
            end
        end

        for (int r = 0; r < tiles_n*AS; r++) begin
            $fwrite(folder_dir_b, "%0d", t);
            for (int c = 0; c < tiles_q*AS; c++) begin 
                $fwrite(folder_dir_b, ",%0d", B[t][r][c]);
            end
            $fwrite(folder_dir_b, "\n");
        end
    endtask

    task automatic init_mem(input int t, input int tiles_m, input int tiles_n, input int tiles_q);
        init_mem_a(t, tiles_m, tiles_n);
        init_mem_b(t, tiles_n, tiles_q);
    endtask

    task automatic reset();
    nRST = 0;
    start = 0;
    repeat (3) @(posedge CLK);
    nRST = 1;

    endtask

    task automatic drive_start();
        start = 1;
        @(posedge CLK);
        @(posedge CLK);

        start = 0;
    endtask 

    task automatic record_output(input int t, input int tiles_m, input int tiles_q);
        logic [ACC_W*AS-1:0] word;
        int tile_index, addr;

        // C(i,j)
        for (int wi = 0; wi < tiles_m; wi++) begin // tile row
            for (int wj = 0; wj < tiles_q; wj++) begin // tile column
                tile_index = wi*tiles_q + wj;

                for (int row = 0; row < AS; row++) begin // one word = one row of the tile
                    addr = tile_index*AS + row;
                    word = DUT.ram.mem_block_c.memory_array[addr];

                    for (int i = 0; i < AS; i++) begin // slot i = column i of that row
                        C[t][wi*AS + row][wj*AS + i] = $signed(word[i*ACC_W +: ACC_W]);
                    end
                end
            end
        end

        for (int r = 0; r < tiles_m*AS; r++) begin
            $fwrite(folder_dir_c, "%0d", t);
            for (int c = 0; c < tiles_q*AS; c++) begin 
                $fwrite(folder_dir_c, ",%0d", C[t][r][c]);
            end
            $fwrite(folder_dir_c, "\n");
        end
    endtask

    initial begin
        int tiles_m;
        int tiles_n;
        int tiles_q;

        // REVIEW: Change these here for different tests with different tile sizes.
        // so far tested: 2, MT, and all randoms (multiple runs). All passed.
        tiles_m = $urandom_range(MT, 2);
        tiles_n = $urandom_range(MT, 2);
        tiles_q = $urandom_range(MT, 2);
            
        force DUT.uc_done_load = '1;
        force DUT.uc_done_rb = '1;
        force DUT.uc_wren_a = '0;
        force DUT.uc_wren_b = '0;
        force DUT.tiles_m = tiles_m;
        force DUT.tiles_n = tiles_n;
        force DUT.tiles_q = tiles_q;

        make_run_dir();

        folder_dir_a = $fopen({run_dir, "/input_a.csv"},  "w");
        folder_dir_b = $fopen({run_dir, "/input_b.csv"},  "w");
        folder_dir_c = $fopen({run_dir, "/output_c.csv"}, "w");

        // HEADER FOR A
        $fwrite(folder_dir_a, "test");
        for (int i = 0; i < tiles_n*AS; i++) begin 
            $fwrite(folder_dir_a, ",a%0d", i);
        end
        $fwrite(folder_dir_a, "\n");

        // HEADER FOR B
        $fwrite(folder_dir_b, "test");
        for (int i = 0; i < tiles_q*AS; i++) begin 
            $fwrite(folder_dir_b, ",b%0d", i);
        end
        $fwrite(folder_dir_b, "\n");

        // HEADER FOR C
        $fwrite(folder_dir_c, "test");
        for (int i = 0; i < AS*tiles_q; i++) begin 
            $fwrite(folder_dir_c, ",c%0d", i);
        end
        $fwrite(folder_dir_c, "\n");

        // EACH TEST MUST BE DONE SEPARATELY
        for (int t = 0; t < NT; t++) begin
            reset();

            build_matrices(t); // matrix t
            init_mem(t, tiles_m, tiles_n, tiles_q);

            @(posedge CLK);

            drive_start();

            // REVIEW: Add record_addr if need for debug

            while(!done) begin
                @(posedge CLK);
            end
            @(posedge CLK);

            record_output(t, tiles_m, tiles_q);
        end

        $fclose(folder_dir_a);
        $fclose(folder_dir_b);
        $fclose(folder_dir_c);
        return_code = $system($sformatf("python3 tb/top_module/tb_top_module_verify.py %s", run_dir));
        if (return_code != 0) begin
            $error("Python check failed (rc=%0d)", return_code);
        end
        $finish;
    end
endmodule
