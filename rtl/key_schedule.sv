// FEAL-8X sequential key schedule: one physical feal_fk instance is reused
// for eight clock cycles to produce K0..K15 (16 bits each).
//
// Protocol:
//   * start accepted on rising edge if busy==0;
//   * input key is latched on that edge;
//   * 8 following rising edges compute 8 FK steps;
//   * done pulses for one cycle after the eighth step;
//   * subkeys_flat is held until the next start (or reset).
//
// Each K_j occupies subkeys_flat[16*j +: 16], K0 at [15:0].
// This is the FEAL-NX 128-bit key schedule restricted to N=8 (FEAL-8X).
module key_schedule (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] key,
    output logic [255:0] subkeys_flat,
    output logic         busy,
    output logic         done
);
    logic [31:0] a_reg;
    logic [31:0] b_reg;
    logic [31:0] d_reg;
    logic [31:0] kr1_reg;
    logic [31:0] kr2_reg;
    logic [2:0]  step_cnt;

    logic [31:0] q;
    logic [31:0] beta;
    logic [31:0] fk_result;
    assign beta = b_reg ^ d_reg ^ q;

    // Steps 0..7 correspond to r=1..8.
    always_comb begin
        case (step_cnt)
            3'd0, 3'd3, 3'd6: q = kr1_reg ^ kr2_reg;
            3'd1, 3'd4, 3'd7: q = kr1_reg;
            default:          q = kr2_reg; // steps 2 and 5
        endcase
    end

    // Exactly one physical FK instance, not eight cascaded instances.
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
            kr1_reg      <= '0;
            kr2_reg      <= '0;
            step_cnt     <= 3'd0;
            subkeys_flat <= '0;
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (start) begin
                    // Capture all of the key, so external changes during
                    // generation cannot mix two different master keys.
                    a_reg        <= key[127:96];
                    b_reg        <= key[95:64];
                    d_reg        <= 32'd0;
                    kr1_reg      <= key[63:32];
                    kr2_reg      <= key[31:0];
                    step_cnt     <= 3'd0;
                    subkeys_flat <= '0;
                    busy         <= 1'b1;
                end
            end else begin
                // B_(r) = FK(A_(r-1), B_(r-1) ^ D_(r-1) ^ Q_r)
                // A_r = B_(r-1), D_r = A_(r-1)
                a_reg <= b_reg;
                d_reg <= a_reg;
                b_reg <= fk_result;

                // 32-bit B_r = { K_(2*r-2), K_(2*r-1) }.
                // Store low-numbered subkey in low-numbered bits.
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
