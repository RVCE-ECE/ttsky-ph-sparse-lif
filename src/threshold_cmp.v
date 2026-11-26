// threshold_cmp.v - comparator: "is the water over the line?"
`default_nettype none
module threshold_cmp (
    input  wire [7:0] vn,
    input  wire [7:0] thr,
    output wire       fire
);
  assign fire = (vn >= thr);
endmodule
