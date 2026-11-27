`timescale 1ns/1ps

// FEAL-8: test vectors from a text file, one fixed 64-bit key.
// Run from sim/: make clean && make sim
// Always check exactly 1000 vectors from feal8_test_vectors.txt.
module tb_feal;
    localparam logic [63:0] TEST_KEY =
        64'h0123456789ABCDEF;
    localparam integer VECTOR_COUNT = 1000;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [63:0] key = TEST_KEY;

    logic [63:0] s_axis_tdata = '0;
    logic        s_axis_tvalid = 1'b0;
    logic         s_axis_tready;
    logic [63:0]  m_axis_tdata;
    logic         m_axis_tvalid;
    logic        m_axis_tready = 1'b1;

    feal_axi dut (.*);
    always #5 clk = ~clk;

    integer tested = 0;
    integer failed = 0;

    // Send one plaintext block and compare the resulting ciphertext.
    task automatic check_vector(
        input logic [63:0] pt,
        input logic [63:0] expected_ct
    );
        integer cycles;
        begin
            // Wait until the device can accept a new block.
            @(negedge clk);
            cycles = 0;
            while (s_axis_tready !== 1'b1 && cycles < 100) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (s_axis_tready !== 1'b1)
                $fatal(1, "TIMEOUT waiting for s_axis_tready");

            s_axis_tdata  = pt;
            s_axis_tvalid = 1'b1;
            @(negedge clk);          // Accepted on the preceding posedge.
            s_axis_tvalid = 1'b0;

            // Wait for ciphertext; output ready is always asserted.
            cycles = 0;
            while (m_axis_tvalid !== 1'b1 && cycles < 100) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (m_axis_tvalid !== 1'b1)
                $fatal(1, "TIMEOUT waiting for ciphertext, PT=%016h", pt);

            tested = tested + 1;
            if (m_axis_tdata !== expected_ct) begin
                failed = failed + 1;
                if (failed <= 10)
                    $display("FAIL PT=%016h expected=%016h got=%016h",
                             pt, expected_ct, m_axis_tdata);
            end
        end
    endtask

    integer fd, chars_read, parsed;
    integer b0, b1, b2, b3, b4, b5, b6, b7;
    integer b8, b9, b10, b11, b12, b13, b14, b15;
    logic [63:0] pt, ct;
    string line;

    initial begin
        fd = $fopen("feal8_test_vectors.txt", "r");
        if (fd == 0)
            $fatal(1, "Cannot open feal8_test_vectors.txt");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Read PT/CT lines. Headers and other lines are ignored.
        while (!$feof(fd) && tested < VECTOR_COUNT) begin
            chars_read = $fgets(line, fd);
            if (chars_read > 0) begin
                // Example: PT: 00 ... 00,  CT: CE ... 52
                parsed = $sscanf(line,
                    "PT: %h %h %h %h %h %h %h %h,  CT: %h %h %h %h %h %h %h %h",
                    b0, b1, b2, b3, b4, b5, b6, b7,
                    b8, b9, b10, b11, b12, b13, b14, b15);

                if (parsed == 16) begin
                    pt = {b0[7:0], b1[7:0], b2[7:0], b3[7:0],
                          b4[7:0], b5[7:0], b6[7:0], b7[7:0]};
                    ct = {b8[7:0], b9[7:0], b10[7:0], b11[7:0],
                          b12[7:0], b13[7:0], b14[7:0], b15[7:0]};
                    check_vector(pt, ct);
                end
            end
        end
        $fclose(fd);

        // Keep this check: otherwise a short file could pass silently.
        if (tested != VECTOR_COUNT)
            $fatal(1, "Only %0d vectors in file; expected %0d", tested, VECTOR_COUNT);

        $display("====================================");
        $display("FEAL-8 test results (one key)");
        $display("Vectors checked: %0d", tested);
        $display("Passed:          %0d", tested - failed);
        $display("Failed:          %0d", failed);
        $display("====================================");
        if (failed != 0)
            $fatal(1, "FAIL: %0d mismatches", failed);
        $display("SUCCESS: all %0d vectors passed", tested);
        $finish;
    end
endmodule
