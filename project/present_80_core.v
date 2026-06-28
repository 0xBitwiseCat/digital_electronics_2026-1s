module present_80_core (
    input  wire        clk,
    input  wire        rst,            // Reset global activo en alto
    input  wire        start,          // Pulso (o nivel) de inicio de cifrado
    input  wire [63:0] plaintext,      // Bloque de texto plano
    input  wire [79:0] key_in,         // Llave maestra
    
    output reg  [63:0] ciphertext,     // Bloque de texto cifrado
    output reg         done            // Pulso limpio de 1 ciclo indicando el fin
);

    // =========================================================================
    // 1. SE AGREGA EL NUEVO ESTADO DE ESPERA
    // =========================================================================
    localparam ST_IDLE       = 3'b000,
               ST_LOAD       = 3'b001,
               ST_ROUND_OP   = 3'b010,
               ST_FINAL_XOR  = 3'b011,
               ST_DONE       = 3'b100,
               ST_STANDBY    = 3'b101; // <--- Nuevo estado

    reg [2:0] current_state, next_state;

    // Registros internos
    reg [63:0] state_reg;
    reg [4:0]  round_counter;
    reg load_key, update_key;

    // Cables del Datapath
    wire [63:0] round_key;
    wire [63:0] xor_round_out;
    wire [63:0] sbox_layer_out;
    wire [63:0] p_layer_out;

    key_schedule master_key_sched (
        .clk(clk), .reset(rst), .key_in(key_in), .load_key(load_key),
        .update_key(update_key), .round_counter(round_counter),
        .current_key(), .round_key(round_key)
    );

    sbox_layer encryption_sbox (
        .data_in(xor_round_out), .data_out(sbox_layer_out)
    );

    p_layer encryption_player (
        .data_in(sbox_layer_out), .data_out(p_layer_out)
    );

    assign xor_round_out = state_reg ^ round_key;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= ST_IDLE;
        else     current_state <= next_state;
    end

    // =========================================================================
    // 2. LÓGICA DE TRANSICIÓN ACTUALIZADA
    // =========================================================================
    always @(*) begin
        next_state = current_state;
        load_key   = 1'b0;
        update_key = 1'b0;

        case (current_state)
            ST_IDLE: begin
                if (start) next_state = ST_LOAD;
            end

            ST_LOAD: begin
                load_key   = 1'b1; 
                next_state = ST_ROUND_OP;
            end

            ST_ROUND_OP: begin
                update_key = 1'b1; 
                if (round_counter == 5'd31) next_state = ST_FINAL_XOR;
                else                        next_state = ST_ROUND_OP;
            end

            ST_FINAL_XOR: begin
                next_state = ST_DONE;
            end

            ST_DONE: begin
                next_state = ST_STANDBY; // <--- Ya no va a IDLE, va a STANDBY
            end

            ST_STANDBY: begin
                // <--- Trampa infinita mientras 'start' siga en 1
                if (start) next_state = ST_STANDBY; 
                else       next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // =========================================================================
    // 3. LÓGICA SECUENCIAL Y CONTROL DE PULSO 'DONE'
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_reg     <= 64'd0;
            round_counter <= 5'd1;
            ciphertext    <= 64'd0;
            done          <= 1'b0;
        end else begin
            case (current_state)
                ST_IDLE: begin
                    done <= 1'b0; // Seguro de apagado
                end
                ST_LOAD: begin
                    state_reg     <= plaintext; 
                    round_counter <= 5'd1;      
                end
                ST_ROUND_OP: begin
                    state_reg     <= p_layer_out;
                    round_counter <= round_counter + 1'b1;
                end
                ST_FINAL_XOR: begin
                    state_reg <= xor_round_out; 
                end
                ST_DONE: begin
                    ciphertext <= state_reg; 
                    done       <= 1'b1; // Se enciende la bandera
                end
                ST_STANDBY: begin
                    done       <= 1'b0; // <--- Se apaga inmediatamente. Esto genera un pulso perfecto de 1 reloj.
                end
            endcase
        end
    end

endmodule
