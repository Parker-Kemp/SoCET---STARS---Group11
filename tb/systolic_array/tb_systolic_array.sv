// Testbench for systolic_array.
// Sends NT tiles back to back, logs what it sent and what came out to two CSVs.
// It does NOT check the math. The Python script does that from the CSVs.
//
//   inputs.csv  : one line per cycle  -> tile, aT0..aT(AS-1), b0..b(AS-1)
//                 (a column of A is a row of A-transpose, so "aT")
//   outputs.csv : one line per C row  -> tile, c0..c(AS-1)
module tb_systolic_array;

    localparam AS = 8;
    localparam DATA_W = 8;
    localparam ACC_W = 32;
    localparam NT = 1000; // number of tiles: 5 edge cases (always minimum of 5) and the rest are random

    logic CLK, nRST;
    logic flag_in, exit_flag;
    logic signed [DATA_W-1:0] a_row_in [AS];
    logic signed [DATA_W-1:0] b_col_in [AS];
    logic signed [ACC_W-1:0] c_out [AS][AS];

    systolic_array #(
        .AS    (AS),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) DUT (
        .CLK      (CLK),
        .nRST     (nRST),
        .flag_in  (flag_in),
        .a_row_in (a_row_in),
        .b_col_in (b_col_in),
        .c_out    (c_out),
        .exit_flag(exit_flag)
    );

    initial CLK = 0;
    always #10 CLK = ~CLK;

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
        run_dir = $sformatf("results/csv_records/systolic_array/%s_run%0d", date, run);
        while ($system({"test -d ", run_dir}) == 0) begin
            run++;
            run_dir = $sformatf("results/csv_records/systolic_array/%s_run%0d", date, run);
        end

        void'($system({"mkdir -p ", run_dir}));
        $display("Saving CSVs to %s", run_dir);
    endtask

    // Test data: A[t] and B[t] are the two matrices of tile t
    logic signed [DATA_W-1:0] A [NT][AS][AS];
    logic signed [DATA_W-1:0] B [NT][AS][AS];

    task automatic build_tiles();
        for (int t = 0; t < NT; t++) begin
            for (int i = 0; i < AS; i++) begin
                for (int j = 0; j < AS; j++) begin
                    case (t)
                        0: begin 
                            A[t][i][j] = DATA_W'(i*AS + j + 1);  
                            B[t][i][j] = (i == j) ? 1 : 0; 
                        end // B = identity, so C must equal A
                        1: begin 
                            A[t][i][j] = 0;
                            B[t][i][j] = 0;
                        end // all zeros
                        2: begin 
                            A[t][i][j] = 127;
                            B[t][i][j] = 127;
                        end // biggest positive
                        3: begin 
                            A[t][i][j] = -128;
                            B[t][i][j] = -128;
                        end // biggest negative
                        4: begin 
                            A[t][i][j] = (((i+j) % 2) == 1) ? 127 : -128;
                            B[t][i][j] = (((i+j) % 2) == 1) ? -128 : 127;
                        end // sign mix
                        default: begin 
                            A[t][i][j] = DATA_W'($urandom());
                            B[t][i][j] = DATA_W'($urandom());
                        end // randoms
                    endcase
                end
            end
        end
    endtask

    // DRIVER side
    int folder_dir_in, folder_dir_out;

    // One cycle of input: column k of A and row k of B for tile t.
    task automatic send_inputs(input int t, input int k);
        @(posedge CLK);
        flag_in = (k == 0); // flag marks element 0 of a tile
        for (int i = 0; i < AS; i++) begin
            a_row_in[i] = A[t][i][k]; // column k of A
            b_col_in[i] = B[t][k][i]; // row k of B
        end

        // WRITING INTO THE CSV FILE:
        $fwrite(folder_dir_in, "%0d", t);
        for (int i = 0; i < AS; i++) begin
            $fwrite(folder_dir_in, ",%0d", a_row_in[i]);
        end

        for (int i = 0; i < AS; i++) begin
            $fwrite(folder_dir_in, ",%0d", b_col_in[i]);
        end
        $fwrite(folder_dir_in, "\n");
    endtask

    // Looping through all rows of that tile WITH FLUSH
    task automatic send_input_stream(input int t);
        for (int k = 0; k < AS; k++) begin // looping through all k from 0 to AS - 1 for the tile
            send_inputs(t, k);
        end

        @(posedge CLK); 
        flag_in = 1; // flush flag, right where the next tile would start
        for (int i = 0; i < AS; i++) begin
            a_row_in[i] = 0;
            b_col_in[i] = 0;
        end
        @(posedge CLK);
        flag_in = 0;
    endtask

    // waits for the second exit flag (the one of the flush and not the feed)
    task automatic wait_second_flag();
        int flag_count;
        logic exit_flag_old;
        flag_count = 0;

        @(posedge CLK);
        while (!(flag_count == 2)) begin
            exit_flag_old = exit_flag;
            @(posedge CLK); // updating
            if (exit_flag && exit_flag != exit_flag_old) begin
                flag_count ++;
            end
        end
    endtask

    // Copy one row of c_out to the CSV.
    task automatic read_outputs(input int t, input int row_num);
        $fwrite(folder_dir_out, "%0d", t);
        for (int j = 0; j < AS; j++) begin 
            $fwrite(folder_dir_out, ",%0d", c_out[row_num][j]);
        end
        $fwrite(folder_dir_out, "\n");
    endtask

    // copy all rows out of c_out one at a time (mimicing the writer\)
    task automatic read_output_stream(input int t);
        for (int r = 0; r < AS; r++) begin
            @(posedge CLK);
            read_outputs(t, r);
        end
    endtask

    initial begin
        make_run_dir();
        build_tiles();

        folder_dir_in  = $fopen({run_dir, "/inputs.csv"},  "w");
        folder_dir_out = $fopen({run_dir, "/outputs.csv"}, "w");

        // header lines
        // INPUT: tile,aT0,aT1,aT2,aT3,aT4,aT5,aT6,aT7,b0,b1,b2,b3,b4,b5,b6,b7
        $fwrite(folder_dir_in, "tile");
        for (int i = 0; i < AS; i++) begin 
            $fwrite(folder_dir_in, ",aT%0d", i);
        end
        for (int i = 0; i < AS; i++) begin
            $fwrite(folder_dir_in, ",b%0d", i);
        end
        $fwrite(folder_dir_in, "\n");

        // OUTPUT: tile,c0,c1,c2,c3,c4,c5,c6,c7
        $fwrite(folder_dir_out, "tile");
        for (int i = 0; i < AS; i++) begin 
            $fwrite(folder_dir_out, ",c%0d", i);
        end
        $fwrite(folder_dir_out, "\n");

        // reset
        nRST    = 0;
        flag_in = 0;
        for (int i = 0; i < AS; i++) begin 
            a_row_in[i] = 0; 
            b_col_in[i] = 0; 
        end
        repeat (3) @(posedge CLK);
        nRST = 1;

        @(posedge CLK);
        for (int t = 0; t < NT; t++) begin
            fork
                begin
                    send_input_stream(t); // FEEDING IN
                end begin
                    wait_second_flag();
                    read_output_stream(t); // READING OUT
                end
            join
        end

        $fclose(folder_dir_in);
        $fclose(folder_dir_out);
        return_code = $system($sformatf("python3 tb/systolic_array/tb_systolic_array_verify.py %s", run_dir));
        if (return_code != 0) begin
            $error("Python check failed (rc=%0d)", return_code);
        end
        $display("Done: %0d tiles sent, CSVs in %s", NT, run_dir);
        $finish;
    end

endmodule
