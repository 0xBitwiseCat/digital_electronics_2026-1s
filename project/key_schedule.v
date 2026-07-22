module key_schedule (
    input  wire        clk,
    input  wire        reset,          // Reset activo en alto
    input  wire [79:0] key_in,         // Llave original de 80 bits que viene del PC (Buffer)
    input  wire        load_key,       // Pulso en ALTO para cargar la llave inicial antes de empezar
    input  wire        update_key,     // Pulso en ALTO para calcular y guardar la llave de la SIGUIENTE ronda
    input  wire [4:0]  round_counter,  // Contador de ronda actual (1 a 31) que viene de tu FSM principal
    
    output reg  [79:0] current_key,    // El estado completo del registro de 80 bits (útil para depuración)
    output wire [63:0] round_key       // Los 64 bits que van hacia el Datapath (add_round_key)
);

    // En PRESENT, la "Round Key" de 64 bits siempre corresponde a los 64 bits 
    // más significativos del registro actual de 80 bits.
    assign round_key = current_key[79:16];

    // =========================================================================
    // LÓGICA COMBINACIONAL: CÁLCULO DE LA SIGUIENTE LLAVE
    // =========================================================================

    // Paso 1: Rotación circular a la izquierda por 61 bits.
    // Matemáticamente, rotar 61 a la izq es lo mismo que rotar 19 a la derecha.
    // En Verilog, esto se logra fácilmente reordenando los cables con concatenación {}.
    wire [79:0] rotated_key;
    assign rotated_key = {current_key[18:0], current_key[79:19]};

    // Paso 2: Sustitución de los 4 bits más significativos usando tu módulo sbox_4bit
    wire [3:0] sbox_out;
    sbox_4bit sbox_ks (
        .data_in  (rotated_key[79:76]),
        .data_out (sbox_out)
    );

    // Ensamblaje de la nueva llave de 80 bits aplicando el Paso 3 (XOR con el contador)
    wire [79:0] next_key;
    
    assign next_key[79:76] = sbox_out;                                   // Los 4 bits que pasaron por la S-Box
    assign next_key[75:20] = rotated_key[75:20];                         // Estos 56 bits pasan intactos
    assign next_key[19:15] = rotated_key[19:15] ^ round_counter;         // XOR con el contador de ronda (5 bits)
    assign next_key[14:0]  = rotated_key[14:0];                          // Los 15 bits menos significativos intactos


    // =========================================================================
    // LÓGICA SECUENCIAL: REGISTRO DE MEMORIA (FLIP-FLOPS)
    // =========================================================================
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Por seguridad, si hay reset, la llave se va a cero
            current_key <= 80'd0;
        end else if (load_key) begin
            // Antes de la Ronda 1, la FSM debe enviar un pulso 'load_key' 
            // para guardar la llave maestra original que se recibió por UART
            current_key <= key_in;
        end else if (update_key) begin
            // Al final de cada ronda, la FSM envía un pulso 'update_key'
            // para actualizar el registro con los cálculos combinacionales
            current_key <= next_key;
        end
    end

endmodule