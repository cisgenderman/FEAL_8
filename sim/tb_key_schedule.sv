`timescale 1ns/1ps
// Verify that one sequential FK instance produces exactly the reference
// 16 subkeys after 8 clock cycles; test key latching and result retention.
module tb_key_schedule;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [127:0] key = '0;
    wire [255:0] subkeys_flat;
    wire busy;
    wire done;

    localparam logic [127:0] KEY_A = 128'h00112233445566778899AABBCCDDEEFF;
    localparam logic [127:0] KEY_B = 128'h0123456789ABCDEF0123456789ABCDEF;
    localparam logic [255:0] SUBKEYS_A = {
        16'h7EAF, 16'h3E99, 16'h8BC9, 16'h86B5,
        16'h4E67, 16'hD19F, 16'h068F, 16'h30C3,
        16'hCE4A, 16'h6537, 16'h78B0, 16'hEC8E,
        16'h87C5, 16'hA8D4, 16'hBAF6, 16'hBA8C
    };
    // Values for KEY_B from the FEAL-NX specification (K0..K15).
    localparam logic [255:0] SUBKEYS_B = {
        16'h653B, 16'hDCA0, 16'h2455, 16'h1BD4,
        16'hEEAC, 16'h9819, 16'h5E76, 16'hFE40,
        16'h7ADE, 16'h4EA4, 16'h523B, 16'h88E5,
        16'h4886, 16'h84E9, 16'h71F9, 16'h7519
    };

    key_schedule dut (
        .clk(clk), .rst_n(rst_n), .start(start), .key(key),
        .subkeys_flat(subkeys_flat), .busy(busy), .done(done)
    );

    task automatic check_schedule(
        input logic [127:0] master_key,
        input logic [255:0] expected
    );
        integer i;
        begin
            @(negedge clk);
            key = master_key;
            start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;
            key = ~master_key; // master key must be latched at start
            if (busy !== 1'b1 || done !== 1'b0)
                $fatal(1, "Schedule did not start");

            for (i = 0; i < 8; i = i + 1) begin
                @(posedge clk);
                @(negedge clk);
                if (i < 7 && (busy !== 1'b1 || done !== 1'b0))
                    $fatal(1, "Schedule ended before 8 FK steps (step=%0d)", i);
            end
            if (busy !== 1'b0 || done !== 1'b1)
                $fatal(1, "Schedule should finish after exactly 8 FK steps");
            if (subkeys_flat !== expected)
                $fatal(1, "Subkey mismatch: got %064h expected %064h",
                    subkeys_flat, expected);

            // Result must remain valid after done pulse, even when key changes.
            repeat (3) @(negedge clk);
            if (done !== 1'b0 || subkeys_flat !== expected)
                $fatal(1, "Schedule did not hold subkeys after done");
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        check_schedule(KEY_B, SUBKEYS_B);
        check_schedule(KEY_A, SUBKEYS_A);
        $display("SUCCESS: iterative key_schedule, 8 FK steps, 2 test keys, latched key and held result");
        $finish;
    end
endmodule
