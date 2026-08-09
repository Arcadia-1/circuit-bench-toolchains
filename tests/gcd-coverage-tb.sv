/* verilator coverage_off */
module gcd_coverage_tb;
  logic        clk;
  logic [31:0] req_msg;
  wire         req_rdy;
  logic        req_val;
  logic        reset;
  wire [15:0]  resp_msg;
  logic        resp_rdy;
  wire         resp_val;

  int unsigned checks;
  logic [31:0] lfsr;

  gcd dut (
    .clk      (clk),
    .req_msg  (req_msg),
    .req_rdy  (req_rdy),
    .req_val  (req_val),
    .reset    (reset),
    .resp_msg (resp_msg),
    .resp_rdy (resp_rdy),
    .resp_val (resp_val)
  );

  always #1 clk = ~clk;

  function automatic logic [15:0] reference_gcd(
    input logic [15:0] lhs,
    input logic [15:0] rhs
  );
    int unsigned a;
    int unsigned b;
    int unsigned remainder;
    begin
      a = {16'b0, lhs};
      b = {16'b0, rhs};
      while (b != 0) begin
        remainder = a % b;
        a = b;
        b = remainder;
      end
      reference_gcd = a[15:0];
    end
  endfunction

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {
      value[30:0],
      value[31] ^ value[21] ^ value[1] ^ value[0]
    };
  endfunction

  task automatic check_response(
    input logic [15:0] lhs,
    input logic [15:0] rhs,
    input logic [15:0] expected
  );
    if (!resp_val) begin
      $fatal(1, "response disappeared for gcd(%0d, %0d)", lhs, rhs);
    end
    if (resp_msg !== expected) begin
      $fatal(
        1,
        "gcd(%0d, %0d): expected %0d, got %0d",
        lhs,
        rhs,
        expected,
        resp_msg
      );
    end
  endtask

  task automatic run_case(
    input logic [15:0] lhs,
    input logic [15:0] rhs,
    input int unsigned backpressure_cycles
  );
    logic [15:0] expected;
    int unsigned latency_cycles;
    begin
      expected = reference_gcd(lhs, rhs);

      while (!req_rdy) begin
        @(negedge clk);
      end
      req_msg = {lhs, rhs};
      req_val = 1'b1;
      @(posedge clk);
      @(negedge clk);
      req_val = 1'b0;

      latency_cycles = 0;
      while (!resp_val) begin
        @(negedge clk);
        latency_cycles++;
        if (latency_cycles > 200000) begin
          $fatal(1, "timeout waiting for gcd(%0d, %0d)", lhs, rhs);
        end
      end

      check_response(lhs, rhs, expected);
      repeat (backpressure_cycles) begin
        @(posedge clk);
        @(negedge clk);
        check_response(lhs, rhs, expected);
      end

      resp_rdy = 1'b1;
      @(posedge clk);
      @(negedge clk);
      resp_rdy = 1'b0;

      if (resp_val) begin
        $fatal(1, "response handshake did not return the DUT to idle");
      end
      checks++;
    end
  endtask

  initial begin
    clk = 1'b0;
    req_msg = 32'b0;
    req_val = 1'b0;
    reset = 1'b1;
    resp_rdy = 1'b0;
    checks = 0;
    lfsr = 32'h1ace_b00c;

    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (3) begin
      @(posedge clk);
      @(negedge clk);
    end

    run_case(16'h0000, 16'h0000, 2);
    run_case(16'h0000, 16'h0001, 0);
    run_case(16'h0001, 16'h0000, 1);
    run_case(16'hffff, 16'h0001, 0);
    run_case(16'h0001, 16'hffff, 3);
    run_case(16'hffff, 16'hffff, 1);
    run_case(16'haaaa, 16'h5555, 2);
    run_case(16'h5555, 16'haaaa, 0);
    run_case(16'h8000, 16'h4000, 1);
    run_case(16'h8001, 16'h7fff, 2);
    run_case(16'hffff, 16'hfffe, 0);
    run_case(16'h002a, 16'h001e, 1);
    run_case(16'h0025, 16'h0258, 2);

    run_case(16'h0002, 16'h0001, 0);
    run_case(16'h0003, 16'h0002, 1);
    run_case(16'h0005, 16'h0003, 2);
    run_case(16'h00e9, 16'h0090, 3);
    run_case(16'h9d80, 16'h61a1, 1);

    for (int bit_index = 0; bit_index < 16; bit_index++) begin
      run_case(16'(1 << bit_index), 16'((1 << ((bit_index + 5) % 16))), bit_index % 3);
      run_case(~16'(1 << bit_index), ~16'((1 << ((bit_index + 9) % 16))), (bit_index + 1) % 3);
    end

    for (int case_index = 0; case_index < 512; case_index++) begin
      lfsr = next_lfsr(lfsr);
      run_case(lfsr[31:16], lfsr[15:0], case_index % 4);
    end

    $display("GCD_COVERAGE_TEST_PASS cases=%0d seed=0x%08x", checks, lfsr);
    $finish;
  end
endmodule
/* verilator coverage_on */
