`timescale 1ns/1ps
// Check K0..K15 against FEAL-NX specification, page 10.
// These are also the first 16 subkeys of FEAL-NX-32 with this key.
module tb_key_schedule;
    logic [127:0] key;
    wire [255:0] subkeys_flat;
    key_schedule dut (.key(key), .subkeys_flat(subkeys_flat));

    initial begin
        key = 128'h0123456789ABCDEF0123456789ABCDEF;
        #10;
        if (subkeys_flat[  0 +:16] !== 16'h7519 ||
            subkeys_flat[ 16 +:16] !== 16'h71F9 ||
            subkeys_flat[ 32 +:16] !== 16'h84E9 ||
            subkeys_flat[ 48 +:16] !== 16'h4886 ||
            subkeys_flat[ 64 +:16] !== 16'h88E5 ||
            subkeys_flat[ 80 +:16] !== 16'h523B ||
            subkeys_flat[ 96 +:16] !== 16'h4EA4 ||
            subkeys_flat[112 +:16] !== 16'h7ADE ||
            subkeys_flat[128 +:16] !== 16'hFE40 ||
            subkeys_flat[144 +:16] !== 16'h5E76 ||
            subkeys_flat[160 +:16] !== 16'h9819 ||
            subkeys_flat[176 +:16] !== 16'hEEAC ||
            subkeys_flat[192 +:16] !== 16'h1BD4 ||
            subkeys_flat[208 +:16] !== 16'h2455 ||
            subkeys_flat[224 +:16] !== 16'hDCA0 ||
            subkeys_flat[240 +:16] !== 16'h653B)
            $fatal(1, "FAIL key schedule: K0..K15 mismatch");

        $display("SUCCESS: 16/16 FEAL-8X subkeys match the specification");
        $finish;
    end
endmodule
