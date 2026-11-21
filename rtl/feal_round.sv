module feal_round (
    input  logic [63:0] data_in,
    input  logic [15:0] subkey, // Теперь 16 бит
    output logic [63:0] data_out
);
    logic [31:0] L, R, f_out;
    assign {L, R} = data_in;

    feal_f f_inst (.alpha(R), .beta(subkey), .result(f_out));
    assign data_out = { R, L ^ f_out };
endmodule