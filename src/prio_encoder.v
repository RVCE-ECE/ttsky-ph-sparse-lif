// prio_encoder.v - index of the lowest set bit (lowest pending input).
`default_nettype none
module prio_encoder (
    input  wire [7:0] req,
    output reg  [2:0] idx
);
  always @* begin
    casez (req)
      8'b???????1: idx = 3'd0;
      8'b??????10: idx = 3'd1;
      8'b?????100: idx = 3'd2;
      8'b????1000: idx = 3'd3;
      8'b???10000: idx = 3'd4;
      8'b??100000: idx = 3'd5;
      8'b?1000000: idx = 3'd6;
      default:     idx = 3'd7;
    endcase
  end
endmodule
