 module crc8_byte (
    input  wire       clk,
    input  wire       rst,       // Reset (actívalo al iniciar una nueva trama)
    input  wire       enable,    // Conectar a la señal 'rx_ready' del uart_rx
    input  wire [7:0] data_in,   // El byte recién recibido
    output reg  [7:0] crc_out    // El hash CRC acumulado
);

    wire [7:0] next_crc;
    wire [7:0] d;
    wire [7:0] c;

    assign d = data_in;
    assign c = crc_out;

    // Ecuaciones combinacionales desenrolladas para CRC-8 (Polinomio 0x07)
    // Calcula los 8 shifts instantáneamente en un solo ciclo de reloj
    assign next_crc[0] = d[7] ^ d[6] ^ d[0] ^ c[0] ^ c[6] ^ c[7];
    assign next_crc[1] = d[6] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[6];
    assign next_crc[2] = d[6] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[6];
    assign next_crc[3] = d[7] ^ d[3] ^ d[2] ^ d[1] ^ c[1] ^ c[2] ^ c[3] ^ c[7];
    assign next_crc[4] = d[4] ^ d[3] ^ d[2] ^ c[2] ^ c[3] ^ c[4];
    assign next_crc[5] = d[5] ^ d[4] ^ d[3] ^ c[3] ^ c[4] ^ c[5];
    assign next_crc[6] = d[6] ^ d[5] ^ d[4] ^ c[4] ^ c[5] ^ c[6];
    assign next_crc[7] = d[7] ^ d[6] ^ d[5] ^ c[5] ^ c[6] ^ c[7];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            crc_out <= 8'd0; // Estado inicial del CRC
        end else if (enable) begin
            crc_out <= next_crc; // Actualiza el CRC con el nuevo byte
        end
    end

endmodule
