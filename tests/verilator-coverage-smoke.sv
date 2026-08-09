module coverage_smoke;
  logic clk = 1'b0;
  logic direction = 1'b0;
  logic [1:0] data = 2'b00;

  always #1 clk = ~clk;

  always_ff @(posedge clk) begin
    if (direction)
      data <= data + 2'b01;
    else
      data <= data - 2'b01;
    direction <= ~direction;
  end

  initial begin
    repeat (12) @(posedge clk);
    $finish;
  end
endmodule
