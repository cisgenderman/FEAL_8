`timescale 1ns/1ps
module tb_feal_f;
    logic [31:0] alpha;
    logic [15:0] beta;
    wire [31:0] result;
    feal_f dut (.alpha(alpha), .beta(beta), .result(result));
    initial begin
        alpha = 32'hF97F1B21;
        beta = 16'h7519;
        #10;
        if (result !== 32'h555CFD7C)
            $fatal(1, "feal_f mismatch: got=%h expected=555CFD7C", result);
        $display("SUCCESS: FEAL F function matches specification");
        $finish;
    end
endmodule
