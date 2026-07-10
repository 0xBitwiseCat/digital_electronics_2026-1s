# digital_electronics_2026-1s
Verilog scripts for Digital Electronics I [Lab/Final Project] 2026-1S - Universidad Nacional de Colombia | Bogota
--

# Actividades
1. Bloque de seleccion de datos de la llave 
2. Bloque XOR datos/llave
3. Bloque de substitution-box
4. Bloque de creacion de llave
5. Iteracion
6. Entrada serial de datos
7. Salida serial de datos
8. Conexion con display
9. Testing
10. Entrega
```mermaid
flowchart TD
    subgraph PC["🖥️ Host PC (Python)"]
        PY_TX["Transmisor\n(19 Bytes: Texto + Llave + CRC)"]
        PY_RX["Receptor\n(9 Bytes: Cifrado + CRC)"]
    end

    subgraph FPGA["⚙️ FPGA (top.v)"]
        
        subgraph UART["Capa Física UART"]
            RX["uart_rx.v"]
            TX["uart_tx.v"]
        end

        subgraph WRAPPER["uart_wrapper.v (Controlador Puente)"]
            FSM["Máquina de Estados (FSM)"]
            CRC["crc8_byte.v"]
            BUF_IN["Registros de Recepción\n(Plaintext + Key)"]
            BUF_OUT["Registros de Transmisión\n(Ciphertext)"]
        end

        subgraph CORE["present_80_core.v (Núcleo Criptográfico)"]
            DP["Datapath (64-bit)"]
            KS["Key Schedule (80-bit)"]
        end
    end

    %% Conexiones PC a FPGA
    PY_TX -- "Cable USB (Serial RX)" --> RX
    TX -- "Cable USB (Serial TX)" --> PY_RX

    %% Interfaz UART a Wrapper
    RX -- "rx_data (8-bit)" --> BUF_IN
    RX -- "rx_ready" --> FSM
    FSM -- "tx_start" --> TX
    BUF_OUT -- "tx_data (8-bit)" --> TX

    %% Validación CRC
    BUF_IN -. "Valida Integridad" .-> CRC
    BUF_OUT -. "Genera Firma Salida" .-> CRC

    %% Interfaz Wrapper a Core
    FSM -- "start" --> CORE
    BUF_IN -- "plaintext (64-bit)\nkey_in (80-bit)" --> DP
    CORE -- "done" --> FSM
    DP -- "ciphertext (64-bit)" --> BUF_OUT

    %% Estilos
    classDef pc fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef fpga fill:#f3e5f5,stroke:#4a148c,stroke-width:2px;
    classDef core fill:#ffe0b2,stroke:#e65100,stroke-width:2px;
    
    class PC pc;
    class FPGA fpga;
    class CORE core;
```

```mermaid
stateDiagram-v2
    direction TB
    
    state "S_IDLE\n(Espera de datos UART)" as IDLE
    state "S_RECV\n(Llenando buffer temporal)" as RECV
    state "S_CHECK_CRC\n(Validación de integridad)" as CHECK_CRC
    state "S_START_CORE\n(Disparo del cifrado)" as START_CORE
    state "S_WAIT_CORE\n(Esperando procesamiento)" as WAIT_CORE
    state "S_LOAD_TX\n(Ensamblaje de respuesta)" as LOAD_TX
    state "S_SEND_BYTE\n(Envío al transceptor TX)" as SEND_BYTE
    state "S_SEND_WAIT\n(Espera de línea libre)" as SEND_WAIT
    state "S_DONE\n(Limpieza y reinicio)" as DONE

    [*] --> IDLE : Reset (rst_n = 0)
    
    IDLE --> RECV : rx_ready = 1
    
    RECV --> RECV : rx_cnt < 19
    RECV --> CHECK_CRC : rx_cnt == 19
    
    CHECK_CRC --> START_CORE : CRC Correcto
    CHECK_CRC --> IDLE : CRC Incorrecto (Aborta trama)
    
    START_CORE --> WAIT_CORE : start = 1
    
    WAIT_CORE --> WAIT_CORE : done = 0
    WAIT_CORE --> LOAD_TX : done = 1 (Cifrado exitoso)
    
    LOAD_TX --> SEND_BYTE : Divide 64-bit en 8 bytes + CRC
    
    SEND_BYTE --> SEND_WAIT : tx_start = 1
    
    SEND_WAIT --> SEND_WAIT : tx_busy = 1
    SEND_WAIT --> SEND_BYTE : tx_busy = 0 & tx_cnt < 9
    SEND_WAIT --> DONE : tx_busy = 0 & tx_cnt == 9
    
    DONE --> IDLE : Transmisión finalizada
```
