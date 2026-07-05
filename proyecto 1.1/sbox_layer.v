module sbox_layer (
    input  wire [63:0] data_in,
    output wire [63:0] data_out
);

    // Variable para generar el hardware iterativo en tiempo de síntesis
    genvar i;

    // El bloque generate crea 16 instancias
    // 16*4 bits = 64 bits para procesar
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            //sbox_4bit procesa 4 bits
            sbox_4bit sbox_inst (
                // separa en bloques de 4 bits la trama de datos
                .data_in  (data_in[(i*4)+3 : i*4]), 
                .data_out (data_out[(i*4)+3 : i*4])
            );
        end
    endgenerate

endmodule