module adder_subtractor_4bit (
    input [3:0] A, B,
    input modo, // 0: Suma, 1: Resta
    output [3:0] Result,
    output Cout_Bout
);
    wire [3:0] B_aux;
    // Si modo=1, invierte B para resta (Complemento a 1)
    assign B_aux = B ^ {4{modo}}; 
    
    // Suma A + B_aux + modo (el modo actúa como Cin)
    assign {Cout_Bout, Result} = A + B_aux + modo;
endmodule
