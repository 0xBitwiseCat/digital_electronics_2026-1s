// =============================================================================
// top.v — Sistema PRESENT-80 con UART (PC) + Pantalla TFT ILI9341 (v2)
//
// Cambios v2:
//   * El display ahora recibe tambien plaintext y llave (ademas del
//     ciphertext) para mostrar la operacion completa en pantalla.
//   * El flujo UART PC <-> FPGA sigue intacto.
// =============================================================================

module top (
    input  wire clk,
    input  wire rst_btn,
    input  wire rx,
    output wire tx,
    output wire [6:0] seg0,
    output wire [6:0] seg1,
    output wire led_recv_done,
    output wire led_crypto_done,
    output wire led_send_done,

    // ---- Pantalla TFT ILI9341 (SPI) ----
    output wire tft_cs,
    output wire tft_rst,
    output wire tft_dc,
    output wire tft_mosi,
    output wire tft_sck,
    output wire tft_led
);
    reg [1:0] rst_sync;
    always @(posedge clk or negedge rst_btn) begin
        if (!rst_btn) rst_sync <= 2'b00;
        else          rst_sync <= {rst_sync[0], 1'b1};
    end
    wire rst_n = rst_sync[1];

    wire [7:0] rx_data;
    wire       rx_ready;
    reg  [7:0] tx_data_r;
    reg        tx_start_r;
    wire       tx_busy;

    uart_rx #(.CLKS_PER_BIT(5208), .HALF_BIT(2604)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(rx),
        .rx_data(rx_data), .rx_ready(rx_ready)
    );
    uart_tx #(.CLKS_PER_BIT(5208)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_start(tx_start_r), .tx_data(tx_data_r),
        .tx(tx), .tx_busy(tx_busy)
    );

    reg [7:0] rx_buf [0:18];
    reg [4:0] rx_cnt;

    reg         crypto_start;
    wire [63:0] ciphertext;
    wire        crypto_done;

    // Plaintext y llave ensamblados desde el buffer de recepcion.
    // Se usan tanto para el core como para la pantalla.
    wire [63:0] plaintext_w = {rx_buf[0],rx_buf[1],rx_buf[2],rx_buf[3],
                               rx_buf[4],rx_buf[5],rx_buf[6],rx_buf[7]};
    wire [79:0] key_w       = {rx_buf[8],rx_buf[9],rx_buf[10],rx_buf[11],rx_buf[12],
                               rx_buf[13],rx_buf[14],rx_buf[15],rx_buf[16],rx_buf[17]};

    present_80_core u_core (
        .clk(clk),
        .rst(~rst_n),
        .start(crypto_start),
        .plaintext(plaintext_w),
        .key_in(key_w),
        .ciphertext(ciphertext),
        .done(crypto_done)
    );

    // =========================================================================
    // Pantalla TFT: muestra plaintext, llave y ciphertext.
    // En el flanco donde crypto_done pulsa, rx_buf sigue estable (no se
    // recibe nada nuevo hasta terminar el envio a la PC), asi que plaintext_w
    // y key_w se capturan de forma segura junto con el ciphertext.
    // =========================================================================
    tft_display u_tft (
        .clk          (clk),
        .plain_in     (plaintext_w),
        .key80_in     (key_w),
        .cipher_in    (ciphertext),
        .cipher_valid (crypto_done),
        .tft_cs       (tft_cs),
        .tft_rst      (tft_rst),
        .tft_dc       (tft_dc),
        .tft_mosi     (tft_mosi),
        .tft_sck      (tft_sck),
        .tft_led      (tft_led)
    );

    function [7:0] crc8_update;
        input [7:0] crc_in;
        input [7:0] data_byte;
        integer i;
        reg [7:0] c;
        begin
            c = crc_in ^ data_byte;
            for (i = 0; i < 8; i = i + 1) begin
                if (c[7]) c = (c << 1) ^ 8'h07;
                else      c = c << 1;
            end
            crc8_update = c;
        end
    endfunction

    wire [7:0] cb0 = ciphertext[63:56];
    wire [7:0] cb1 = ciphertext[55:48];
    wire [7:0] cb2 = ciphertext[47:40];
    wire [7:0] cb3 = ciphertext[39:32];
    wire [7:0] cb4 = ciphertext[31:24];
    wire [7:0] cb5 = ciphertext[23:16];
    wire [7:0] cb6 = ciphertext[15:8];
    wire [7:0] cb7 = ciphertext[7:0];

    reg [7:0] crc_calc;
    always @(*) begin
        crc_calc = 8'h00;
        crc_calc = crc8_update(crc_calc, cb0);
        crc_calc = crc8_update(crc_calc, cb1);
        crc_calc = crc8_update(crc_calc, cb2);
        crc_calc = crc8_update(crc_calc, cb3);
        crc_calc = crc8_update(crc_calc, cb4);
        crc_calc = crc8_update(crc_calc, cb5);
        crc_calc = crc8_update(crc_calc, cb6);
        crc_calc = crc8_update(crc_calc, cb7);
    end

    reg [3:0] tx_cnt;
    reg [7:0] tx_byte_sel;
    always @(*) begin
        case (tx_cnt)
            4'd0: tx_byte_sel = cb0;
            4'd1: tx_byte_sel = cb1;
            4'd2: tx_byte_sel = cb2;
            4'd3: tx_byte_sel = cb3;
            4'd4: tx_byte_sel = cb4;
            4'd5: tx_byte_sel = cb5;
            4'd6: tx_byte_sel = cb6;
            4'd7: tx_byte_sel = cb7;
            4'd8: tx_byte_sel = crc_calc;
            default: tx_byte_sel = 8'h00;
        endcase
    end

    localparam S_IDLE    = 3'd0;
    localparam S_RECV    = 3'd1;
    localparam S_START_C = 3'd2;
    localparam S_WAIT_C  = 3'd3;
    localparam S_WAIT_TX = 3'd4;
    localparam S_SEND    = 3'd5;

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            rx_cnt       <= 5'd0;
            tx_cnt       <= 4'd0;
            crypto_start <= 1'b0;
            tx_start_r   <= 1'b0;
            tx_data_r    <= 8'd0;
        end else begin
            tx_start_r   <= 1'b0;
            crypto_start <= 1'b0;
            case (state)
                S_IDLE: begin
                    rx_cnt       <= 5'd0;
                    tx_cnt       <= 4'd0;
                    crypto_start <= 1'b0;
                    if (rx_ready) begin
                        rx_buf[0] <= rx_data;
                        rx_cnt    <= 1;
                        state     <= S_RECV;
                    end
                end
                S_RECV: begin
                    if (rx_ready) begin
                        rx_buf[rx_cnt] <= rx_data;
                        if (rx_cnt == 18) state <= S_START_C;
                        else rx_cnt <= rx_cnt + 1'b1;
                    end
                end
                S_START_C: begin
                    crypto_start <= 1'b1;
                    state        <= S_WAIT_C;
                end
                S_WAIT_C: begin
                    if (crypto_done) begin
                        tx_cnt <= 4'd0;
                        state  <= S_WAIT_TX;
                    end
                end
                S_WAIT_TX: begin
                    if (!tx_busy) begin
                        tx_data_r  <= tx_byte_sel;
                        tx_start_r <= 1'b1;
                        state      <= S_SEND;
                    end
                end
                S_SEND: begin
                    if (tx_busy) begin
                        if (tx_cnt == 8) state <= S_IDLE;
                        else begin
                            tx_cnt <= tx_cnt + 1'b1;
                            state  <= S_WAIT_TX;
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    // ---- LEDs de diagnostico: muestra progreso de recepcion ----
    reg latch_first_byte, latch_mid, latch_recv;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latch_first_byte <= 1'b0;
            latch_mid        <= 1'b0;
            latch_recv       <= 1'b0;
        end else begin
            if (rx_ready)              latch_first_byte <= 1'b1;  // llego al menos 1 byte
            if (rx_cnt >= 5'd9)        latch_mid        <= 1'b1;  // llego a la mitad (9 bytes)
            if (state == S_START_C)    latch_recv       <= 1'b1;  // llegaron los 19 completos
        end
    end
    assign led_recv_done   = latch_first_byte;
    assign led_crypto_done = latch_mid;
    assign led_send_done   = latch_recv;
    assign seg0 = 7'b1111111;
    assign seg1 = 7'b1111111;
endmodule
