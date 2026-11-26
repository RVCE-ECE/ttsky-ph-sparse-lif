// membrane_file.v - 4 x 8-bit membrane potentials, one read port and one write port selected by n.
`default_nettype none
module membrane_file (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clr,       // synchronous clear of all potentials
    input  wire       wr_en,
    input  wire [1:0] n,
    input  wire [7:0] wdata,
    output reg  [7:0] vn         // potential of neuron n
);
  reg [7:0] v0, v1, v2, v3;

  always @(posedge clk) begin
    if (!rst_n || clr) begin
      v0 <= 8'd0; v1 <= 8'd0; v2 <= 8'd0; v3 <= 8'd0;
    end else if (wr_en) begin
      case (n)
        2'd0: v0 <= wdata;
        2'd1: v1 <= wdata;
        2'd2: v2 <= wdata;
        default: v3 <= wdata;
      endcase
    end
  end

  always @* begin
    case (n)
      2'd0: vn = v0;
      2'd1: vn = v1;
      2'd2: vn = v2;
      default: vn = v3;
    endcase
  end
endmodule
