
module tb_compute_controller;

    localparam AS = 8;

    localparam FT = 0; 
    localparam FK = 1; 
    localparam FJ = 2; 
    localparam FI = 3;

    localparam WR = 0; 
    localparam WJ = 1; 
    localparam WI = 2;

    // INPUTS
    logic CLK = 0, nRST;
    logic [7:0] tiles_m, tiles_n, tiles_q;
    logic exit_flag, start; // TODO: determine when to send exit_flag (should be something like 2(AS - 1) after entry_flag)
    // OUTPUTS:
    logic [15 + $clog2(AS):0] addr_A, addr_B, addr_C;
    logic wdone, entry_flag;

    int num_test_computes = 0;

    string run_dir;

    task automatic make_run_dir();
        string date;
        int folder_dir, run;

        // Get today's date from the OS. Write it to a temp file, read it back, delete the file.
        void'($system("date +%Y-%m-%d > .sim_date.txt"));
        folder_dir = $fopen(".sim_date.txt", "r");
        void'($fscanf(folder_dir, "%s", date));
        $fclose(folder_dir);
        void'($system("rm -f .sim_date.txt"));

        // Find the first run number that doesn't have a folder yet today.
        // "test -d" checks whether a folder exists, and returns 0 if it does.
        run = 1;
        run_dir = $sformatf("results/csv_records/compute_controller/%s_run%0d", date, run);
        while ($system({"test -d ", run_dir}) == 0) begin
            run++;
            run_dir = $sformatf("results/csv_records/compute_controller/%s_run%0d", date, run);
        end

        void'($system({"mkdir -p ", run_dir}));
        $display("Saving CSVs to %s", run_dir);
    endtask

    // Clock generation
    always #(10) CLK++;

    compute_controller #(
        .AS(8)
     ) DUT (
        .CLK       (CLK),
        .nRST      (nRST),
        .tiles_m   (tiles_m),
        .tiles_n   (tiles_n),
        .tiles_q   (tiles_q),
        .exit_flag (exit_flag),
        .start     (start),
        .addr_A    (addr_A),
        .addr_B    (addr_B),
        .addr_C    (addr_C),
        .entry_flag(entry_flag),
        .wdone     (wdone)
    );

    task reset();
    begin
        nRST = '0;
        repeat(2) @(posedge CLK);
        nRST = '1;
        @(posedge CLK);
        #(1);
    end
    endtask

    task reset_signals();
    begin
        start = 0;
        exit_flag = 0;
    end
    endtask
    
    task drive_compute(
        input logic [7:0] tiles_m_temp, tiles_n_temp, tiles_q_temp
    );
    begin
        logic [15 + $clog2(AS):0] exp_addr_A, exp_addr_B, exp_addr_C;
        logic [15 + $clog2(AS):0] acc_addr_A, acc_addr_B, acc_addr_C;
        int cycles;
        int file_handle;
        int passed_cycles;
        int cycle_limit;

        cycles = 0;
        passed_cycles = 0;

        start = 1; // sending start
        tiles_m = tiles_m_temp;
        tiles_n = tiles_n_temp;
        tiles_q = tiles_q_temp;
        @(posedge CLK);
        @(posedge CLK);
        start = 0;

        // writing cvs sheet
        file_handle = $fopen($sformatf("%s/test_%0d.csv", run_dir, num_test_computes), "w");
        
        // This is just an error check to make sure it successfully created it
        if (file_handle == 0) begin
            $display("FATAL ERROR: Simulator failed to create the file!");
            $finish; // Stop simulation before trying to write to an invalid file
        end
        // HEADER: REVIEW:
        $fwrite(file_handle, "Cycle #,Passed #,tiles_m,tiles_n,tiles_q,Expected addr_A,Actual addr_A,Expected addr_B,Actual addr_B,Expected addr_C,Actual addr_C\n");

        while (!wdone) begin
            // timeout check
            cycle_limit = int'(2 * tiles_m * tiles_n * tiles_q * AS + 100);
            if (cycles >= cycle_limit) begin
                $error("Timeout: output signals not set properly for a compute operation, exceeded %0d cycles",
                cycle_limit);
                return;
            end

            if (entry_flag) begin
                fork
                    begin
                        repeat (AS) @(posedge CLK);
                        exit_flag <= 1'b1;
                        @(posedge CLK);
                        exit_flag <= 0;
                    end
                join_none
            end
            
            // store data
            // Feeder and writer having the exact same num of characters is so neat.
            exp_addr_A = DUT.feeder.count[FT] + DUT.feeder.count[FK] * AS + tiles_n * DUT.feeder.count[FI] * AS;
            exp_addr_B = DUT.feeder.count[FT] + DUT.feeder.count[FK] * AS + tiles_n * DUT.feeder.count[FJ] * AS;
            exp_addr_C = DUT.writer.count[WR] + DUT.writer.count[WJ] * AS + tiles_q * DUT.writer.count[WI] * AS;

            acc_addr_A = addr_A;
            acc_addr_B = addr_B;
            acc_addr_C = addr_C;

            if ((exp_addr_A === acc_addr_A) && (exp_addr_B === acc_addr_B) && (exp_addr_C === acc_addr_C)) begin
                passed_cycles++;
            end else begin
                $display("FAIL: Cycle #%0d", cycles);
            end

            // output into file
            $fwrite(file_handle, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", 
            cycles, passed_cycles, tiles_m, tiles_n, tiles_q, 
            exp_addr_A, acc_addr_A, exp_addr_B, acc_addr_B, 
            exp_addr_C, acc_addr_C);
    
            // cycle
            @(posedge CLK);
            cycles++;
        end

        $fclose(file_handle);
        num_test_computes++;
    end
    endtask

    initial begin
        $dumpfile("waveform.fst");

        nRST = 1'b1;

        make_run_dir();

        // TESTING EDGE CASES.
        for (int i = 0; i < 8; i++) begin
            reset_signals();
            reset();
            drive_compute(
              i[2] ? 16 : 1,
              i[1] ? 16 : 1,
              i[0] ? 16 : 1
            );
        end

        $display("%0d COMPUTES DONE", num_test_computes);

        $finish;
    end

endmodule
