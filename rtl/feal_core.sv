// FEAL-8X cryptographic core independent of the AXI-style interface.
// start is sampled on a rising edge when busy==0.
// busy=1 during eight iterative Feistel rounds.
// done pulses for one clock when ciphertext is ready.
// ciphertext is held until the next completed encryption.
module feal_core (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] key,
    input  logic [63:0]  plaintext,
    output logic [63:0]  ciphertext,
    output logic         busy,
    output logic         done
);
    wire [255:0] incoming_subkeys;
    logic [255:0] active_subkeys;

    key_schedule ks (
        .key(key),
        .subkeys_flat(incoming_subkeys)
    );

    // Round registers and one physical round instance reused 8 times.
    logic [63:0] lr_reg;
    logic [2:0] round_cnt;
    wire  [63:0] round_out;
    wire  [15:0] current_subkey = active_subkeys[16*round_cnt +: 16];

    feal_round round_inst (
        .data_in(lr_reg),
        .subkey(current_subkey),
        .data_out(round_out)
    );

    wire [31:0] pre_l = {incoming_subkeys[8*16 +: 16],
                         incoming_subkeys[9*16 +: 16]};
    wire [31:0] pre_r = {incoming_subkeys[10*16 +: 16],
                         incoming_subkeys[11*16 +: 16]};
    wire [31:0] init_l = plaintext[63:32] ^ pre_l;
    wire [31:0] init_r = plaintext[31:0] ^ pre_r ^ init_l;

    wire [31:0] post_l = {active_subkeys[12*16 +: 16],
                          active_subkeys[13*16 +: 16]};
    wire [31:0] post_r = {active_subkeys[14*16 +: 16],
                          active_subkeys[15*16 +: 16]};

    // Use round_out, not lr_reg, for the *last* round's ciphertext.
    wire [63:0] finished_block = {
        round_out[31:0] ^ post_l,
        round_out[63:32] ^ round_out[31:0] ^ post_r
    };

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_subkeys <= '0;
            lr_reg         <= '0;
            round_cnt      <= 3'd0;
            ciphertext     <= '0;
            busy           <= 1'b0;
            done           <= 1'b0;
        end else begin
            done <= 1'b0; // One-cycle completion pulse.
            if (!busy) begin
                if (start) begin
                    active_subkeys <= incoming_subkeys;
                    lr_reg <= {init_l, init_r};
                    round_cnt <= 3'd0;
                    busy <= 1'b1;
                end
            end else begin
                lr_reg <= round_out;
                if (round_cnt == 3'd7) begin
                    ciphertext <= finished_block;
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    round_cnt <= round_cnt + 3'd1;
                end
            end
        end
    end
endmodule
