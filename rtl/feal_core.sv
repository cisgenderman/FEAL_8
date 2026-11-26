// FEAL-8X cryptographic core, independent of AXI-Stream transport.
//
// On start (when idle):
//   - Key cache HIT:  use the saved 256-bit subkeys immediately.
//   - Key cache MISS: run sequential key_schedule for 8 FK steps, then
//                     save 256-bit subkeys and begin the 8 Feistel rounds.
// Both cases encrypt the plaintext sampled on the accepted start edge.
// Changing key or plaintext externally while busy cannot affect the block.
// Key cache survives between blocks and is invalidated by rst_n=0.
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
    localparam logic [1:0] IDLE = 2'd0;
    localparam logic [1:0] WAIT_KEYS = 2'd1;
    localparam logic [1:0] ROUNDS = 2'd2;

    logic [1:0] state;

    // Cache: full 128-bit key tag + 256-bit associated subkeys.
    logic [127:0] cached_key;
    logic         cache_valid;
    logic [255:0] active_subkeys;

    // Preserve the incoming request during a cache miss. The key schedule
    // itself latches the master key on the same accepted start edge.
    logic [127:0] requested_key;
    logic [63:0]  pending_plaintext;

    logic [255:0] generated_subkeys;
    logic         ks_busy;
    logic         ks_done;
    logic         cache_hit;
    assign cache_hit = cache_valid && (key == cached_key);

    // Only start the generator for a new key. Not triggered by cached hits.
    logic ks_start;
    assign ks_start = (state == IDLE) && start && !cache_hit;

    key_schedule ks_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ks_start),
        .key(key),
        .subkeys_flat(generated_subkeys),
        .busy(ks_busy),
        .done(ks_done)
    );

    // In IDLE the pre-processing uses cached keys and live plaintext.
    // In WAIT_KEYS it uses freshly generated keys and latched plaintext.
    logic [255:0] init_subkeys;
    logic [63:0]  init_plaintext;
    assign init_subkeys =
        (state == WAIT_KEYS) ? generated_subkeys : active_subkeys;
    assign init_plaintext =
        (state == WAIT_KEYS) ? pending_plaintext : plaintext;

    logic [31:0] pre_l, pre_r;
    logic [31:0] init_l, init_r;
    assign pre_l  = {init_subkeys[8*16 +: 16],
                     init_subkeys[9*16 +: 16]};
    assign pre_r  = {init_subkeys[10*16 +: 16],
                     init_subkeys[11*16 +: 16]};
    assign init_l = init_plaintext[63:32] ^ pre_l;
    assign init_r = init_plaintext[31:0] ^ pre_r ^ init_l;

    logic [63:0] lr_reg;
    logic [2:0]  round_cnt;
    logic [15:0] current_subkey;
    logic [63:0] round_out;
    assign current_subkey = active_subkeys[16*round_cnt +: 16];

    feal_round round_inst (
        .data_in(lr_reg),
        .subkey(current_subkey),
        .data_out(round_out)
    );

    logic [31:0] post_l, post_r;
    logic [63:0] finished_block;
    assign post_l = {active_subkeys[12*16 +: 16],
                     active_subkeys[13*16 +: 16]};
    assign post_r = {active_subkeys[14*16 +: 16],
                     active_subkeys[15*16 +: 16]};
    assign finished_block = {
        round_out[31:0] ^ post_l,
        round_out[63:32] ^ round_out[31:0] ^ post_r
    };

    assign busy = (state != IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            active_subkeys    <= '0;
            cached_key        <= '0;
            cache_valid       <= 1'b0;
            requested_key     <= '0;
            pending_plaintext <= '0;
            lr_reg            <= '0;
            round_cnt         <= 3'd0;
            ciphertext        <= '0;
            done              <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        if (cache_hit) begin
                            // Key already expanded; start rounds immediately.
                            lr_reg    <= {init_l, init_r};
                            round_cnt <= 3'd0;
                            state     <= ROUNDS;
                        end else begin
                            // Generator samples `key` on this edge.
                            requested_key     <= key;
                            pending_plaintext <= plaintext;
                            state             <= WAIT_KEYS;
                        end
                    end
                end
                WAIT_KEYS: begin
                    if (ks_done) begin
                        active_subkeys <= generated_subkeys;
                        cached_key     <= requested_key;
                        cache_valid    <= 1'b1;
                        lr_reg         <= {init_l, init_r};
                        round_cnt      <= 3'd0;
                        state          <= ROUNDS;
                    end
                end
                ROUNDS: begin
                    lr_reg <= round_out;
                    if (round_cnt == 3'd7) begin
                        // Consume the eighth round's combinational output.
                        ciphertext <= finished_block;
                        done       <= 1'b1;
                        state      <= IDLE;
                    end else begin
                        round_cnt <= round_cnt + 3'd1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
