// Common FEAL nonlinear byte functions. Shared by feal_f and feal_fk.
// This is a SystemVerilog package, not a separately instantiated circuit.
package feal_s_pkg;
    function automatic logic [7:0] rot2(input logic [7:0] x);
        rot2 = {x[5:0], x[7:6]};
    endfunction

    function automatic logic [7:0] s0(
        input logic [7:0] x,
        input logic [7:0] y
    );
        logic [7:0] sum;
        begin
            sum = x + y; // Addition modulo 256 (8-bit truncation)
            s0 = rot2(sum);
        end
    endfunction

    function automatic logic [7:0] s1(
        input logic [7:0] x,
        input logic [7:0] y
    );
        logic [7:0] sum;
        begin
            sum = x + y + 8'd1; // Addition modulo 256
            s1 = rot2(sum);
        end
    endfunction
endpackage
