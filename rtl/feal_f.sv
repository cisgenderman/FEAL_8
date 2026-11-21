// FEAL round function f: 32-bit data + 16-bit round key -> 32-bit result.
module feal_f (
    input  logic [31:0] alpha,
    input  logic [15:0] beta,
    output logic [31:0] result
);
    import feal_s_pkg::*;

    logic [7:0] a0, a1, a2, a3;
    logic [7:0] b0, b1;
    logic [7:0] f0, f1, f2, f3;

    always_comb begin
        {a0, a1, a2, a3} = alpha;
        {b0, b1} = beta;
        f1 = a1 ^ b0;
        f2 = a2 ^ b1;
        f1 = f1 ^ a0;
        f2 = f2 ^ a3;
        f1 = s1(f1, f2);
        f2 = s0(f2, f1);
        f0 = s0(a0, f1);
        f3 = s1(a3, f2);
        result = {f0, f1, f2, f3};
    end
endmodule
