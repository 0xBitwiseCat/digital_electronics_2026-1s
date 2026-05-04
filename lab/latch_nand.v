module latch_nand (
    input Sn, Rn, // Entradas activas en bajo (0 activa)
    output Q, Qn
);
    assign Q = ~(Sn & Qn);
    assign Qn = ~(Rn & Q);
endmodule
