`timescale 1ns/1ps

// FEAL-8X: test vectors from a text file, one fixed 128-bit key.
// Run from sim/: make clean && make sim
// Optional: vvp ../build/feal.vvp +COUNT=50
//           vvp ../build/feal.vvp +COUNT=0 (all vectors)
//           vvp ../build/feal.vvp +VECFILE=path/to/file.txt
module tb_feal;
    localparam logic [127:0] TEST_KEY =
        128'h00112233445566778899AABBCCDDEEFF;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [127:0] key = TEST_KEY;

    logic [63:0] s_axis_tdata = '0;
    logic        s_axis_tvalid = 1'b0;
    wire         s_axis_tready;
    wire [63:0]  m_axis_tdata;
    wire         m_axis_tvalid;
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

    integer fd, chars_read, parsed, limit;
    integer b0, b1, b2, b3, b4, b5, b6, b7;
    integer b8, b9, b10, b11, b12, b13, b14, b15;
    logic [127:0] file_key;
    logic [63:0] pt, ct;
    bit key_found = 1'b0;
    string line;
    string vector_path;

    initial begin
        vector_path = "feal8_test_vectors.txt";
        if ($value$plusargs("VECFILE=%s", vector_path)) begin end
        limit = 1000;
        if ($value$plusargs("COUNT=%d", limit)) begin end
        if (limit < 0)
            $fatal(1, "COUNT must be >= 0");

        fd = $fopen(vector_path, "r");
        if (fd == 0)
            $fatal(1, "Cannot open vector file: %s", vector_path);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        while (!$feof(fd) && (limit == 0 || tested < limit)) begin
            chars_read = $fgets(line, fd);
            if (chars_read > 0) begin
                // Example: KEY = 00 11 22 ... EE FF
                parsed = $sscanf(line,
                    "KEY = %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h",
                    b0, b1, b2, b3, b4, b5, b6, b7,
                    b8, b9, b10, b11, b12, b13, b14, b15);

                if (parsed == 16) begin
                    file_key = {b0[7:0], b1[7:0], b2[7:0], b3[7:0],
                                b4[7:0], b5[7:0], b6[7:0], b7[7:0],
                                b8[7:0], b9[7:0], b10[7:0], b11[7:0],
                                b12[7:0], b13[7:0], b14[7:0], b15[7:0]};
                    if (file_key !== TEST_KEY)
                        $fatal(1, "Unexpected key in vector file: %032h", file_key);
                    key_found = 1'b1;
                end else begin
                    // Example: PT: 00 ... 00,  CT: 7E ... C4
                    parsed = $sscanf(line,
                        "PT: %h %h %h %h %h %h %h %h,  CT: %h %h %h %h %h %h %h %h",
                        b0, b1, b2, b3, b4, b5, b6, b7,
                        b8, b9, b10, b11, b12, b13, b14, b15);
                    if (parsed == 16) begin
                        if (!key_found)
                            $fatal(1, "PT/CT encountered before KEY header");
                        pt = {b0[7:0], b1[7:0], b2[7:0], b3[7:0],
                              b4[7:0], b5[7:0], b6[7:0], b7[7:0]};
                        ct = {b8[7:0], b9[7:0], b10[7:0], b11[7:0],
                              b12[7:0], b13[7:0], b14[7:0], b15[7:0]};
                        check_vector(pt, ct);
                    end
                end
            end
        end
        $fclose(fd);

        if (!key_found || tested == 0)
            $fatal(1, "No valid KEY or PT/CT vectors found");
        if (limit != 0 && tested != limit)
            $fatal(1, "Only %0d vectors in file; requested %0d", tested, limit);

        $display("====================================");
        $display("FEAL-8X test results (one key)");
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
