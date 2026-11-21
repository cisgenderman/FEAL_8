`timescale 1ns/1ps

// Unified FEAL-8X testbench.
//   make sim                          -> 3 smoke tests + 1000 file vectors
//   vvp ../build/feal.vvp +COUNT=50   -> 3 smoke tests + 50 file vectors
//   vvp ../build/feal.vvp +COUNT=0    -> 3 smoke tests + all file vectors
//   vvp ../build/feal.vvp +WAVES      -> also write feal_wave.vcd
// Default input: ./feal8_test_vectors.txt (original PT:/CT: text format).
// Can override with +VECFILE=path/to/file.txt
module tb_feal;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [127:0] key = '0;
    logic [63:0] s_axis_tdata = '0;
    logic s_axis_tvalid = 1'b0;
    wire  s_axis_tready;
    wire [63:0] m_axis_tdata;
    wire  m_axis_tvalid;
    logic m_axis_tready = 1'b0;

    localparam logic [127:0] TEST_KEY =
        128'h00112233445566778899AABBCCDDEEFF;

    feal_axi dut (.*);
    always #5 clk = ~clk;

    // Every block is sent and received using valid/ready handshakes.
    // With hold_output=1, also verify that the ciphertext is held stable
    // while the consumer deasserts ready. Return match status to the caller.
    task automatic check_block(
        input logic [63:0] plaintext,
        input logic [63:0] expected,
        input logic [127:0] block_key,
        input bit hold_output,
        output bit matched
    );
        integer cycles;
        begin
            @(negedge clk);
            cycles = 0;
            while (s_axis_tready !== 1'b1 && cycles < 100) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (s_axis_tready !== 1'b1)
                $fatal(1, "TIMEOUT: input ready PT=%016h", plaintext);

            key = block_key;
            s_axis_tdata = plaintext;
            s_axis_tvalid = 1'b1;
            @(posedge clk);  // accepted; ready was 1 throughout the cycle
            @(negedge clk);
            s_axis_tvalid = 1'b0;
            if (hold_output)
                key = ~block_key; // check that key is latched on input

            cycles = 0;
            while (m_axis_tvalid !== 1'b1 && cycles < 100) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (m_axis_tvalid !== 1'b1)
                $fatal(1, "TIMEOUT: output valid PT=%016h", plaintext);

            // A ciphertext mismatch is counted by the caller, not fatal.
            // Use case equality: X/Z must also count as an error.
            matched = (m_axis_tdata === expected);

            if (hold_output) begin
                repeat (3) begin
                    @(negedge clk);
                    if (m_axis_tvalid !== 1'b1 || m_axis_tdata !== expected)
                        $fatal(1, "FAIL: output unstable during backpressure");
                end
            end

            m_axis_tready = 1'b1;
            @(posedge clk);  // output accepted
            @(negedge clk);
            m_axis_tready = 1'b0;
        end
    endtask

    integer fd;
    integer chars_read;
    integer parsed;
    integer count;
    integer tested;
    integer failed;
    bit matched;
    integer b0, b1, b2, b3, b4, b5, b6, b7;
    integer b8, b9, b10, b11, b12, b13, b14, b15;
    logic [127:0] file_key;
    logic [63:0] plaintext;
    logic [63:0] expected;
    bit key_found;
    string line;
    string vector_path;

    initial begin
        // VCD is optional, to avoid extremely large files with 1M vectors.
        if ($test$plusargs("WAVES")) begin
            $dumpfile("feal_wave.vcd");
            $dumpvars(0, tb_feal);
        end

        vector_path = "feal8_test_vectors.txt";
        if ($value$plusargs("VECFILE=%s", vector_path)) begin end
        count = 1000;  // +COUNT=0 means every record until EOF
        if ($value$plusargs("COUNT=%d", count)) begin end
        if (count < 0)
            $fatal(1, "COUNT must be nonnegative");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Smoke tests, including backpressure and changing the key mid-block.
        check_block(64'h0000000000000000, 64'h7EF56729231C9DC4, TEST_KEY, 1'b1, matched);
        if (!matched) $fatal(1, "FAIL: smoke test 1");
        check_block(64'h0000000100000000, 64'h49F7043D549F1F23, TEST_KEY, 1'b1, matched);
        if (!matched) $fatal(1, "FAIL: smoke test 2");
        check_block(64'h0000000200000000, 64'hCFB202BFD5575E15, TEST_KEY, 1'b1, matched);
        if (!matched) $fatal(1, "FAIL: smoke test 3");

        // Read the ORIGINAL FEAL text file, no converter or .mem files needed.
        fd = $fopen(vector_path, "r");
        if (fd == 0)
            $fatal(1, "Cannot open %s. Place file in sim/ or use +VECFILE=path", vector_path);
        tested = 0;
        failed = 0;
        key_found = 1'b0;
        file_key = '0;
        while (!$feof(fd) && (count == 0 || tested < count)) begin
            chars_read = $fgets(line, fd);
            if (chars_read == 0) begin
                // End of file; $feof is checked at the next loop condition.
            end else begin
                // KEY = 00 11 22 ... FF (16 bytes)
                parsed = $sscanf(line,
                    "KEY = %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h",
                    b0, b1, b2, b3, b4, b5, b6, b7,
                    b8, b9, b10, b11, b12, b13, b14, b15);
                if (parsed == 16) begin
                    file_key = {b0[7:0], b1[7:0], b2[7:0], b3[7:0],
                                b4[7:0], b5[7:0], b6[7:0], b7[7:0],
                                b8[7:0], b9[7:0], b10[7:0], b11[7:0],
                                b12[7:0], b13[7:0], b14[7:0], b15[7:0]};
                    key_found = 1'b1;
                end else begin
                    // PT: 00 00 ... 00,  CT: 7E F5 ... C4 (16 bytes)
                    parsed = $sscanf(line,
                        "PT: %h %h %h %h %h %h %h %h,  CT: %h %h %h %h %h %h %h %h",
                        b0, b1, b2, b3, b4, b5, b6, b7,
                        b8, b9, b10, b11, b12, b13, b14, b15);
                    if (parsed == 16) begin
                        if (!key_found)
                            $fatal(1, "PT/CT encountered before KEY header");
                        plaintext = {b0[7:0], b1[7:0], b2[7:0], b3[7:0],
                                     b4[7:0], b5[7:0], b6[7:0], b7[7:0]};
                        expected = {b8[7:0], b9[7:0], b10[7:0], b11[7:0],
                                    b12[7:0], b13[7:0], b14[7:0], b15[7:0]};
                        check_block(plaintext, expected, file_key, 1'b0, matched);
                        tested = tested + 1;
                        if (!matched)
                            failed = failed + 1;
                    end
                end
            end
        end
        $fclose(fd);

        if (!key_found)
            $fatal(1, "No KEY header in vector file");
        if (tested == 0)
            $fatal(1, "No PT/CT vectors recognized");
        if (count != 0 && tested != count)
            $fatal(1, "File contains only %0d vectors; requested %0d", tested, count);

        $display("====================================");
        $display("FEAL-8X test results");
        $display("Vectors checked: %0d", tested);
        $display("Passed:          %0d", tested - failed);
        $display("Failed:          %0d", failed);
        $display("====================================");
        if (failed != 0)
            $fatal(1, "FAIL: %0d mismatches out of %0d vectors", failed, tested);
        $display("SUCCESS: all %0d file vectors passed", tested);
        $finish;
    end
endmodule
