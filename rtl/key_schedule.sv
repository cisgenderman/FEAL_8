// FEAL-8 sequential key schedule for a 64-bit master key.
// One feal_fk combinational instance is reused over eight clock cycles.
// Produces K0..K15, each 16 bits, in subkeys_flat[16*i +: 16].
//
// On start (when !busy), the 64-bit master key is captured.
// On the eight subsequent rising edges, the schedule computes U1..U8.
// After step 8, done pulses for one cycle; subkeys remain stable.
//
// FEAL-8, Handbook of Applied Cryptography, algorithm 7.95:
// U[-2]=0, U[-1]=key[63:32], U[0]=key[31:0].
// U[r] = FK(U[r-2], U[r-1] ^ U[r-3]) for r=1..8.
// K[2*r-2]=U[r][31:16], K[2*r-1]=U[r][15:0].
module key_schedule (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [63:0]  key,
    output logic [255:0] subkeys_flat,
    output logic         busy,
    output logic         done
);
    // While computing step r:
    // a_reg=U[r-2], b_reg=U[r-1], d_reg=U[r-3].
    logic [31:0] a_reg;
    logic [31:0] b_reg;
    logic [31:0] d_reg;
    logic [2:0]  step_cnt;

    logic [31:0] beta;
    logic [31:0] fk_result;
    assign beta = b_reg ^ d_reg;

    // Only one FK block exists in the hardware.
    feal_fk fk_inst (
        .alpha(a_reg),
        .beta(beta),
        .result(fk_result)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg        <= '0;
            b_reg        <= '0;
            d_reg        <= '0;
            step_cnt     <= 3'd0;
            subkeys_flat <= '0;
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    a_reg        <= key[63:32]; // U[-1]
                    b_reg        <= key[31:0];  // U[0]
                    d_reg        <= 32'd0;      // U[-2]
                    step_cnt     <= 3'd0;
                    subkeys_flat <= '0;
                    busy         <= 1'b1;
                end
            end else begin
                // Produce one 32-bit U[r] = two 16-bit subkeys.
                a_reg <= b_reg;
                d_reg <= a_reg;
                b_reg <= fk_result;

                // Lowest 16 bits are K0, next 16 bits K1, etc.
                subkeys_flat[32*step_cnt +: 32] <=
                    {fk_result[15:0], fk_result[31:16]};

                if (step_cnt == 3'd7) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    step_cnt <= step_cnt + 3'd1;
                end
            end
        end
    end
endmodule
