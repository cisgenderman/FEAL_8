// FEAL-8X key schedule: 128-bit master key -> K0..K15 (16 bits each).
// Uses the 128-bit FEAL-NX key schedule with N=8 iterations:
//   Q_r = KR1^KR2 (r=1,4,7,...), KR1 (r=2,5,8,...), KR2 (r=3,6,9,...)
//   D_r=A_(r-1), A_r=B_(r-1), B_r=fK(A_(r-1), B_(r-1)^D_(r-1)^Q_r)
// Note: the FEAL-NX PDF mandates N>=32 for the NX designation;
//       the 8-round/128-bit-key variant is conventionally FEAL-8X.
module key_schedule (
    input  logic [127:0] key,
    output wire [255:0] subkeys_flat
);
    wire [31:0] a [0:8];
    wire [31:0] b [0:8];
    wire [31:0] d [0:8];
    wire [31:0] kr1, kr2;

    assign a[0] = key[127:96];
    assign b[0] = key[95:64];
    assign d[0] = 32'b0;
    assign kr1  = key[63:32];
    assign kr2  = key[31:0];

    for (genvar i = 0; i < 8; i = i + 1) begin : stage
        wire [31:0] q;
        wire [31:0] beta;

        if (i % 3 == 0) begin : q_xor
            assign q = kr1 ^ kr2;
        end else if (i % 3 == 1) begin : q_left
            assign q = kr1;
        end else begin : q_right
            assign q = kr2;
        end

        assign beta = b[i] ^ d[i] ^ q;
        feal_fk fk_i (
            .alpha(a[i]),
            .beta(beta),
            .result(b[i+1])
        );
        assign a[i+1] = b[i];
        assign d[i+1] = a[i];

        // Each K_j occupies [16*j +: 16], i.e. K0 at the lowest 16 bits.
        // B_(i+1) = {K_(2*i), K_(2*i+1)} in MSB-first order.
        
        assign subkeys_flat[32*i +: 32] = {b[i+1][15:0], b[i+1][31:16]};
    end
endmodule
