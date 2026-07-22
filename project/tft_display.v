// =============================================================================
// tft_display.v  (v2) — TFT ILI9341 para el proyecto PRESENT-80
//
// Muestra en pantalla TODA la operacion de cifrado:
//   Linea 1: "FPGA ENCRYPTOR"          (verde)
//   Linea 2: "PT"                      (cian)
//   Linea 3: plaintext  en hex (16)    (blanco)
//   Linea 4: "KEY"                     (cian)
//   Linea 5: llave      en hex (20)    (blanco)
//   Linea 6: "CT"                      (cian)
//   Linea 7: ciphertext en hex (16)    (amarillo)

//
// Geometria: fuente 8x8 escalada 2x -> celdas de 16x16 px.
// Todas las lineas y columnas estan alineadas a multiplos de 16, de modo que:
//   linea      = px[7:4]
//   caracter   = py[8:4]
//   fila glifo = px[3:1]
//   col  glifo = py[3:1]
// =============================================================================

module tft_display (
    input  wire        clk,
    input  wire [63:0] plain_in,      // plaintext recibido
    input  wire [79:0] key80_in,      // llave de 80 bits recibida
    input  wire [63:0] cipher_in,     // ciphertext calculado
    input  wire        cipher_valid,  // pulso de 1 ciclo (crypto_done)
    output reg         tft_cs,
    output reg         tft_rst,
    output reg         tft_dc,
    output reg         tft_mosi,
    output reg         tft_sck,
    output wire        tft_led
);

assign tft_led = 1'b1;

// -----------------------------------------------------------------------------
// Captura de datos + contador de solicitudes de redibujo
// -----------------------------------------------------------------------------
reg [63:0] plain_reg  = 64'd0;
reg [79:0] key_reg    = 80'd0;
reg [63:0] cipher_reg = 64'd0;
reg [7:0]  req_cnt    = 8'd0;

always @(posedge clk) begin
    if (cipher_valid) begin
        plain_reg  <= plain_in;
        key_reg    <= key80_in;
        cipher_reg <= cipher_in;
        req_cnt    <= req_cnt + 1'b1;
    end
end

// Lado FSM: reconocimiento y buffers de dibujo (congelados por cuadro)
reg [7:0]  ack_cnt     = 8'd0;
reg [63:0] plain_draw  = 64'd0;
reg [79:0] key_draw    = 80'd0;
reg [63:0] cipher_draw = 64'd0;
reg        data_shown  = 1'b0;   // ya hay datos que mostrar

// -----------------------------------------------------------------------------
// Registros de la FSM (misma estructura que el pantallatop original)
// -----------------------------------------------------------------------------
reg [7:0]  shift_reg = 8'd0;
reg [3:0]  bit_cnt   = 4'd0;
reg [24:0] delay_cnt = 25'd0;
reg [6:0]  cmd_idx   = 7'd0;
reg [4:0]  state     = 5'd0;
reg [8:0]  px        = 9'd0;
reg [8:0]  py        = 9'd0;

initial begin
    tft_rst  = 1'b0;
    tft_cs   = 1'b1;
    tft_sck  = 1'b0;
    tft_dc   = 1'b0;
    tft_mosi = 1'b0;
end

localparam RESET1   = 5'd0,
           RESET2   = 5'd1,
           CMD_LOAD = 5'd2,
           CMD_SEND = 5'd3,
           CMD_CLK  = 5'd4,
           CMD_NEXT = 5'd5,
           DELAY    = 5'd6,
           PIX_H    = 5'd7,
           PIX_H_TX = 5'd8,
           PIX_H_CK = 5'd9,
           PIX_L    = 5'd10,
           PIX_L_TX = 5'd11,
           PIX_L_CK = 5'd12,
           PIX_NEXT = 5'd13,
           DONE     = 5'd14;

// -----------------------------------------------------------------------------
// Secuencia de inicializacion ILI9341 (identica al proyecto original)
// -----------------------------------------------------------------------------
reg [8:0] cmds [0:45];

initial begin
    cmds[0]  = {1'b0, 8'hCF};
    cmds[1]  = {1'b1, 8'h00};
    cmds[2]  = {1'b1, 8'hC1};
    cmds[3]  = {1'b1, 8'h30};
    cmds[4]  = {1'b0, 8'hED};
    cmds[5]  = {1'b1, 8'h64};
    cmds[6]  = {1'b1, 8'h03};
    cmds[7]  = {1'b1, 8'h12};
    cmds[8]  = {1'b1, 8'h81};
    cmds[9]  = {1'b0, 8'hE8};
    cmds[10] = {1'b1, 8'h85};
    cmds[11] = {1'b1, 8'h00};
    cmds[12] = {1'b1, 8'h78};
    cmds[13] = {1'b0, 8'hCB};
    cmds[14] = {1'b1, 8'h39};
    cmds[15] = {1'b1, 8'h2C};
    cmds[16] = {1'b1, 8'h00};
    cmds[17] = {1'b1, 8'h34};
    cmds[18] = {1'b1, 8'h02};
    cmds[19] = {1'b0, 8'hF7};
    cmds[20] = {1'b1, 8'h20};
    cmds[21] = {1'b0, 8'hEA};
    cmds[22] = {1'b1, 8'h00};
    cmds[23] = {1'b1, 8'h00};
    cmds[24] = {1'b0, 8'h36};
    cmds[25] = {1'b1, 8'hC8};
    cmds[26] = {1'b0, 8'h3A};
    cmds[27] = {1'b1, 8'h55};
    cmds[28] = {1'b0, 8'hB1};
    cmds[29] = {1'b1, 8'h00};
    cmds[30] = {1'b1, 8'h1B};
    cmds[31] = {1'b0, 8'hB6};
    cmds[32] = {1'b1, 8'h0A};
    cmds[33] = {1'b1, 8'h82};
    cmds[34] = {1'b1, 8'h27};
    cmds[35] = {1'b0, 8'h11}; // Sleep Out
    cmds[36] = {1'b0, 8'h29}; // Display ON
    cmds[37] = {1'b0, 8'h2A}; // Column set  <-- punto de reentrada para redibujar
    cmds[38] = {1'b1, 8'h00};
    cmds[39] = {1'b1, 8'h00};
    cmds[40] = {1'b1, 8'h00};
    cmds[41] = {1'b1, 8'hEF};
    cmds[42] = {1'b0, 8'h2B}; // Row set
    cmds[43] = {1'b1, 8'h00};
    cmds[44] = {1'b1, 8'h00};
    cmds[45] = {1'b1, 8'h01};
end

// -----------------------------------------------------------------------------
// ROM de fuente 8x8. Codigos: 0-15 = '0'-'F', 16=G, 17=N, 18=O, 19=P,
// 20=R, 21=T, 22=Y, 23=K, otro = espacio.
// Fila 0 = parte superior. Bit 7 = columna izquierda.
// -----------------------------------------------------------------------------
function [7:0] font8x8;
    input [4:0] ch;
    input [2:0] row;
    reg [63:0] g;
    begin
        case (ch)
            5'd0 : g = 64'h3C_66_6E_76_66_66_3C_00; // 0
            5'd1 : g = 64'h18_38_18_18_18_18_7E_00; // 1
            5'd2 : g = 64'h3C_66_06_0C_18_30_7E_00; // 2
            5'd3 : g = 64'h3C_66_06_1C_06_66_3C_00; // 3
            5'd4 : g = 64'h0C_1C_3C_6C_7E_0C_0C_00; // 4
            5'd5 : g = 64'h7E_60_7C_06_06_66_3C_00; // 5
            5'd6 : g = 64'h1C_30_60_7C_66_66_3C_00; // 6
            5'd7 : g = 64'h7E_06_0C_18_30_30_30_00; // 7
            5'd8 : g = 64'h3C_66_66_3C_66_66_3C_00; // 8
            5'd9 : g = 64'h3C_66_66_3E_06_0C_38_00; // 9
            5'd10: g = 64'h18_3C_66_66_7E_66_66_00; // A
            5'd11: g = 64'h7C_66_66_7C_66_66_7C_00; // B
            5'd12: g = 64'h3C_66_60_60_60_66_3C_00; // C
            5'd13: g = 64'h78_6C_66_66_66_6C_78_00; // D
            5'd14: g = 64'h7E_60_60_7C_60_60_7E_00; // E
            5'd15: g = 64'h7E_60_60_7C_60_60_60_00; // F
            5'd16: g = 64'h3C_66_60_6E_66_66_3E_00; // G
            5'd17: g = 64'h66_76_7E_7E_6E_66_66_00; // N
            5'd18: g = 64'h3C_66_66_66_66_66_3C_00; // O
            5'd19: g = 64'h7C_66_66_7C_60_60_60_00; // P
            5'd20: g = 64'h7C_66_66_7C_6C_66_66_00; // R
            5'd21: g = 64'h7E_18_18_18_18_18_18_00; // T
            5'd22: g = 64'h66_66_3C_18_18_18_18_00; // Y
            5'd23: g = 64'h66_6C_78_70_78_6C_66_00; // K
            default: g = 64'h00_00_00_00_00_00_00_00; // espacio
        endcase
        font8x8 = g[{3'd7 - row, 3'b000} +: 8];
    end
endfunction

// Texto del titulo: "FPGA ENCRYPTOR" (14 caracteres)
function [4:0] title_char;
    input [3:0] idx;
    begin
        case (idx)
            4'd0 : title_char = 5'd15; // F
            4'd1 : title_char = 5'd19; // P
            4'd2 : title_char = 5'd16; // G
            4'd3 : title_char = 5'd10; // A
            4'd4 : title_char = 5'd31; // (espacio)
            4'd5 : title_char = 5'd14; // E
            4'd6 : title_char = 5'd17; // N
            4'd7 : title_char = 5'd12; // C
            4'd8 : title_char = 5'd20; // R
            4'd9 : title_char = 5'd22; // Y
            4'd10: title_char = 5'd19; // P
            4'd11: title_char = 5'd21; // T
            4'd12: title_char = 5'd18; // O
            4'd13: title_char = 5'd20; // R
            default: title_char = 5'd31;
        endcase
    end
endfunction

// -----------------------------------------------------------------------------
// Layout de pantalla (todo alineado a rejilla de 16x16 px)
//
//   lin = px[7:4]      (numero de linea de texto, 0..14)
//   cidx = py[8:4]     (numero de columna de caracter, 0..19)
//
//   lin 1  : titulo,   cidx 3..16  (14 chars centrados)
//   lin 3  : "PT",     cidx 1..2
//   lin 4  : PT hex,   cidx 2..17  (16 chars)
//   lin 6  : "KEY",    cidx 1..3
//   lin 7  : KEY hex,  cidx 0..19  (20 chars = 80 bits)
//   lin 9  : "CT",     cidx 1..2
//   lin 10 : CT hex,   cidx 2..17  (16 chars)
// -----------------------------------------------------------------------------
wire [3:0] lin  = px[7:4];
wire [4:0] cidx = py[8:4];
wire [2:0] frow = px[3:1];
wire [2:0] fcol = py[3:1];

// Indices de nibble para las lineas hex
wire [4:0] nib16_5 = cidx - 5'd2;                 // 0..15 en lineas de 16 chars
wire [3:0] nib16   = nib16_5[3:0];
wire [3:0] pt_nib  = plain_draw [{~nib16, 2'b00} +: 4];
wire [3:0] ct_nib  = cipher_draw[{~nib16, 2'b00} +: 4];

wire [4:0] kidx     = 5'd19 - cidx;               // 0..19 en la linea de llave
wire [6:0] key_base = {kidx, 2'b00};              // kidx * 4
wire [3:0] key_nib  = key_draw[key_base +: 4];

// Indice de caracter dentro del titulo
wire [4:0] tidx5 = cidx - 5'd3;

localparam COL_NONE     = 3'd0,
           COL_VERDE    = 3'd1,
           COL_CIAN     = 3'd2,
           COL_BLANCO   = 3'd3,
           COL_AMARILLO = 3'd4;

reg [4:0] pix_ch;
reg [2:0] pix_col_sel;

always @(*) begin
    pix_ch      = 5'd31;      // espacio
    pix_col_sel = COL_NONE;

    if (lin == 4'd1 && cidx >= 5'd3 && cidx <= 5'd16) begin
        pix_ch      = title_char(tidx5[3:0]);
        pix_col_sel = COL_VERDE;
    end else if (data_shown) begin
        case (lin)
            4'd3: begin // "PT"
                if      (cidx == 5'd1) begin pix_ch = 5'd19; pix_col_sel = COL_CIAN; end
                else if (cidx == 5'd2) begin pix_ch = 5'd21; pix_col_sel = COL_CIAN; end
            end
            4'd4: begin // plaintext hex
                if (cidx >= 5'd2 && cidx <= 5'd17) begin
                    pix_ch      = {1'b0, pt_nib};
                    pix_col_sel = COL_BLANCO;
                end
            end
            4'd6: begin // "KEY"
                if      (cidx == 5'd1) begin pix_ch = 5'd23; pix_col_sel = COL_CIAN; end
                else if (cidx == 5'd2) begin pix_ch = 5'd14; pix_col_sel = COL_CIAN; end
                else if (cidx == 5'd3) begin pix_ch = 5'd22; pix_col_sel = COL_CIAN; end
            end
            4'd7: begin // llave hex: 20 caracteres, linea completa
                pix_ch      = {1'b0, key_nib};
                pix_col_sel = COL_BLANCO;
            end
            4'd9: begin // "CT"
                if      (cidx == 5'd1) begin pix_ch = 5'd12; pix_col_sel = COL_CIAN; end
                else if (cidx == 5'd2) begin pix_ch = 5'd21; pix_col_sel = COL_CIAN; end
            end
            4'd10: begin // ciphertext hex
                if (cidx >= 5'd2 && cidx <= 5'd17) begin
                    pix_ch      = {1'b0, ct_nib};
                    pix_col_sel = COL_AMARILLO;
                end
            end
            default: ;
        endcase
    end
end

wire [7:0] glyph  = font8x8(pix_ch, frow);
wire       pix_on = (pix_col_sel != COL_NONE) && glyph[3'd7 - fcol];

// Colores RGB565
reg [7:0] byte_hi, byte_lo;
always @(*) begin
    byte_hi = 8'h00;
    byte_lo = 8'h00;
    if (pix_on) begin
        case (pix_col_sel)
            COL_VERDE:    {byte_hi, byte_lo} = 16'h07E0;
            COL_CIAN:     {byte_hi, byte_lo} = 16'h07FF;
            COL_BLANCO:   {byte_hi, byte_lo} = 16'hFFFF;
            COL_AMARILLO: {byte_hi, byte_lo} = 16'hFFE0;
            default:      {byte_hi, byte_lo} = 16'h0000;
        endcase
    end
end

// -----------------------------------------------------------------------------
// FSM principal (misma estructura y temporizacion SPI que pantallatop)
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    case (state)

        RESET1: begin
            tft_rst   <= 1'b0;
            tft_cs    <= 1'b1;
            tft_sck   <= 1'b0;
            delay_cnt <= delay_cnt + 1'b1;
            if (delay_cnt == 25'h1FFFFFF) begin
                tft_rst   <= 1'b1;
                delay_cnt <= 25'd0;
                state     <= RESET2;
            end
        end

        RESET2: begin
            delay_cnt <= delay_cnt + 1'b1;
            if (delay_cnt == 25'h1FFFFFF) begin
                delay_cnt <= 25'd0;
                cmd_idx   <= 7'd0;
                state     <= CMD_LOAD;
            end
        end

        CMD_LOAD: begin
            if (cmd_idx < 7'd46) begin
                tft_dc    <= cmds[cmd_idx][8];
                shift_reg <= cmds[cmd_idx][7:0];
                bit_cnt   <= 4'd7;
                tft_cs    <= 1'b0;
                tft_sck   <= 1'b0;
                tft_mosi  <= cmds[cmd_idx][7];
                state     <= CMD_SEND;
            end else if (cmd_idx == 7'd46) begin
                // Ultimo dato de Row set: 0x3F
                tft_dc    <= 1'b1;
                shift_reg <= 8'h3F;
                bit_cnt   <= 4'd7;
                tft_cs    <= 1'b0;
                tft_sck   <= 1'b0;
                tft_mosi  <= 1'b0;
                state     <= CMD_SEND;
            end else if (cmd_idx == 7'd47) begin
                // Memory Write: 0x2C
                tft_dc    <= 1'b0;
                shift_reg <= 8'h2C;
                bit_cnt   <= 4'd7;
                tft_cs    <= 1'b0;
                tft_sck   <= 1'b0;
                tft_mosi  <= 1'b0;
                state     <= CMD_SEND;
            end else begin
                // Comienza el barrido de pixeles
                px    <= 9'd0;
                py    <= 9'd0;
                state <= PIX_H;
            end
        end

        CMD_SEND: begin
            tft_sck <= 1'b1;
            state   <= CMD_CLK;
        end

        CMD_CLK: begin
            tft_sck <= 1'b0;
            if (bit_cnt == 4'd0) begin
                tft_cs <= 1'b1;
                state  <= CMD_NEXT;
            end else begin
                bit_cnt   <= bit_cnt - 1'b1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= CMD_SEND;
            end
        end

        CMD_NEXT: begin
            cmd_idx <= cmd_idx + 1'b1;
            if (cmd_idx == 7'd35) begin
                // Delay de ~120 ms tras Sleep Out
                delay_cnt <= 25'd0;
                state     <= DELAY;
            end else begin
                state <= CMD_LOAD;
            end
        end

        DELAY: begin
            delay_cnt <= delay_cnt + 1'b1;
            if (delay_cnt == 25'd6000000) begin
                delay_cnt <= 25'd0;
                state     <= CMD_LOAD;
            end
        end

        // ===== BYTE ALTO del pixel =====
        PIX_H: begin
            tft_dc    <= 1'b1;
            tft_cs    <= 1'b0;
            tft_sck   <= 1'b0;
            bit_cnt   <= 4'd7;
            shift_reg <= byte_hi;
            tft_mosi  <= byte_hi[7];
            state     <= PIX_H_TX;
        end

        PIX_H_TX: begin
            tft_sck <= 1'b1;
            state   <= PIX_H_CK;
        end

        PIX_H_CK: begin
            tft_sck <= 1'b0;
            if (bit_cnt == 4'd0) begin
                state <= PIX_L;
            end else begin
                bit_cnt   <= bit_cnt - 1'b1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= PIX_H_TX;
            end
        end

        // ===== BYTE BAJO del pixel =====
        PIX_L: begin
            bit_cnt   <= 4'd7;
            tft_sck   <= 1'b0;
            shift_reg <= byte_lo;
            tft_mosi  <= byte_lo[7];
            state     <= PIX_L_TX;
        end

        PIX_L_TX: begin
            tft_sck <= 1'b1;
            state   <= PIX_L_CK;
        end

        PIX_L_CK: begin
            tft_sck <= 1'b0;
            if (bit_cnt == 4'd0) begin
                state <= PIX_NEXT;
            end else begin
                bit_cnt   <= bit_cnt - 1'b1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= PIX_L_TX;
            end
        end

        // ===== Siguiente pixel (px eje rapido, py eje lento) =====
        PIX_NEXT: begin
            if (px == 9'd239) begin
                px <= 9'd0;
                if (py == 9'd319) begin
                    py     <= 9'd0;
                    tft_cs <= 1'b1;
                    state  <= DONE;
                end else begin
                    py    <= py + 1'b1;
                    state <= PIX_H;
                end
            end else begin
                px    <= px + 1'b1;
                state <= PIX_H;
            end
        end

        // ===== Pantalla lista: si hay datos pendientes, redibuja =====
        DONE: begin
            tft_cs <= 1'b1;
            if (ack_cnt != req_cnt) begin
                ack_cnt     <= req_cnt;       // reconoce TODO lo pendiente
                plain_draw  <= plain_reg;     // congela los datos del cuadro
                key_draw    <= key_reg;
                cipher_draw <= cipher_reg;
                data_shown  <= 1'b1;
                cmd_idx     <= 7'd37;         // reentra: Column -> Row -> 0x2C -> pixeles
                state       <= CMD_LOAD;
            end
        end

        default: state <= RESET1;

    endcase
end

endmodule