module comparator_4bit (
    input [3:0] A, B,
    output reg A_gt_B,
    output reg A_lt_B,
    output reg A_eq_B
);
    always @(*) begin
        A_gt_B = 0; A_lt_B = 0; A_eq_B = 0;
        if (A > B)      A_gt_B = 1;
        else if (A < B) A_lt_B = 1;
        else            A_eq_B = 1;
    end
endmodule
