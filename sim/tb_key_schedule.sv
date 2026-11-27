`timescale 1ns/1ps

// Verify the 64-bit FEAL-8 schedule: 8 FK steps, published 16 subkeys,
// key latching, stable output and a second independent master key.
module tb_key_schedule;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [63:0] key = '0;
    logic [255:0] subkeys_flat;
    logic busy;
    logic done;

    localparam logic [63:0] KEY_A = 64'h0123456789ABCDEF;
    localparam logic [63:0] KEY_B = 64'h0011223344556677;
    // Published subkeys: Handbook of Applied Cryptography, example 7.99.
    localparam logic [255:0] SUBKEYS_A = {
        16'h0CB5, 16'hA8D5, 16'h479B, 16'h22CD,
        16'h9D4C, 16'hAC50, 16'hECB7, 16'h8B2A,
        16'hAD25, 16'h26EB, 16'hB9C7, 16'h45A5,
        16'h1AEC, 16'hF17C, 16'hCA36, 16'hDF3B
    };
    // Independent software reference, sim/gen_vectors.py.
    localparam logic [255:0] SUBKEYS_B = {
        16'h3456, 16'h8A50, 16'hBBCB, 16'h2C59,
        16'hBE9B, 16'hD926, 16'h2206, 16'h1DE1,
        16'h09CB, 16'hA4B5, 16'hD6A2, 16'hA82A,
        16'h7737, 16'h2540, 16'h6711, 16'hEF9D
    };

    key_schedule dut (
        .clk(clk), .rst_n(rst_n), .start(start), .key(key),
        .subkeys_flat(subkeys_flat), .busy(busy), .done(done)
    );

    task automatic check_schedule(
        input logic [63:0] master_key,
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
            key = ~master_key; // Must not affect the ongoing expansion.
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

            repeat (3) @(negedge clk);
            if (done !== 1'b0 || subkeys_flat !== expected)
                $fatal(1, "Schedule did not hold subkeys after done");
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        check_schedule(KEY_A, SUBKEYS_A);
        check_schedule(KEY_B, SUBKEYS_B);
        $display("SUCCESS: FEAL-8 key_schedule; published subkeys, 8 FK steps, 2 keys");
        $finish;
    end
endmodule
