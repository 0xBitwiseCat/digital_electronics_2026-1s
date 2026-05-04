module latch_nor (
    input S, R,
    output Q, Qn
);
    assign Q = ~(R | Qn);
    assign Qn = ~(S | Q);
endmodule
