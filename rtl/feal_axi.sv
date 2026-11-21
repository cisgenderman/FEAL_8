// AXI-stream-like wrapper around feal_core.
// Holds the output transaction until m_axis_tvalid && m_axis_tready.
// One 64-bit input block -> one 64-bit output block.
module feal_axi (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [127:0] key,
    input  logic [63:0]  s_axis_tdata,
    input  logic         s_axis_tvalid,
    output wire          s_axis_tready,
    output wire [63:0]   m_axis_tdata,
    output wire          m_axis_tvalid,
    input  logic         m_axis_tready
);
    typedef enum logic [1:0] {WAIT_INPUT, WAIT_CORE, SEND_OUTPUT} state_t;
    state_t state;

    logic [63:0] output_reg;
    wire [63:0] core_ciphertext;
    wire core_busy;
    wire core_done;

    assign s_axis_tready = (state == WAIT_INPUT) && !core_busy;
    assign m_axis_tvalid = (state == SEND_OUTPUT);
    assign m_axis_tdata  = output_reg;

    wire core_start = s_axis_tvalid && s_axis_tready;

    feal_core core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(core_start),
        .key(key),
        .plaintext(s_axis_tdata),
        .ciphertext(core_ciphertext),
        .busy(core_busy),
        .done(core_done)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT_INPUT;
            output_reg <= '0;
        end else begin
            case (state)
                WAIT_INPUT: begin
                    if (core_start)
                        state <= WAIT_CORE;
                end
                WAIT_CORE: begin
                    if (core_done) begin
                        output_reg <= core_ciphertext;
                        state <= SEND_OUTPUT;
                    end
                end
                SEND_OUTPUT: begin
                    if (m_axis_tready)
                        state <= WAIT_INPUT;
                end
                default: state <= WAIT_INPUT;
            endcase
        end
    end
endmodule
