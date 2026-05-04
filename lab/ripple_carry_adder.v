module ripple_carry_adder (
    input [3:0] A, B,
    input Cin,
    output [3:0] Sum,
    output Cout
);
    wire c1, c2, c3;

    // Instancias lógicas de sumadores bit a bit
    assign {c1, Sum[0]} = A[0] + B[0] + Cin;
    assign {c2, Sum[1]} = A[1] + B[1] + c1;
    assign {c3, Sum[2]} = A[2] + B[2] + c2;
    assign {Cout, Sum[3]} = A[3] + B[3] + c3;
endmodule
