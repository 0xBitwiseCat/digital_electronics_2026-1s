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
    %% Definición de estilos para el informe
    classDef state fill:#e1f5fe,stroke:#0288d1,stroke-width:2px,color:#000
    classDef decision fill:#fff9c4,stroke:#fbc02d,stroke-width:2px,color:#000
    classDef action fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000
    classDef error fill:#ffebee,stroke:#d32f2f,stroke-width:2px,color:#000
    classDef start_end fill:#333,stroke:#000,stroke-width:2px,color:#fff

    %% Nodos principales
    START(((Reset / Inicio))):::start_end --> IDLE
    
    IDLE["<b>S_IDLE</b><br>Espera de primer byte"]:::state --> RX_READY{"rx_ready == 1?"}:::decision
    RX_READY -- No --> IDLE
    
    RX_READY -- Sí --> RECV["<b>S_RECV</b><br>Recibe byte y acumula<br>crc_calc al vuelo"]:::state
    RECV --> CHECK_COUNT{"byte_cnt == 18?"}:::decision
    
    CHECK_COUNT -- No --> WAIT_NEXT["Espera siguiente byte"]:::state
    WAIT_NEXT --> RX_READY_2{"rx_ready == 1?"}:::decision
    RX_READY_2 -- No --> WAIT_NEXT
    RX_READY_2 -- Sí --> RECV
    
    CHECK_COUNT -- Sí (Trama completa) --> CHECK_CRC["<b>S_CHECK_CRC</b><br>Verificación de integridad"]:::state
    CHECK_CRC --> IS_CRC_OK{"crc_calc == rx_buf[18]?"}:::decision
    
    IS_CRC_OK -- No --> ERROR["Error de CRC<br>Trama Descartada"]:::error
    ERROR --> IDLE
    
    IS_CRC_OK -- Sí --> START_CORE["<b>S_START_CORE</b><br>Ensambla Llave y Plaintext<br>start = 1"]:::action
    START_CORE --> WAIT_CORE["<b>S_WAIT_CORE</b><br>Procesando PRESENT-80"]:::state
    
    WAIT_CORE --> IS_DONE{"done == 1?"}:::decision
    IS_DONE -- No --> WAIT_CORE
    
    IS_DONE -- Sí --> PREP_TX["<b>S_PREP_TX</b><br>Empaqueta Ciphertext<br>Calcula CRC TX"]:::action
    PREP_TX --> SEND_WAIT["<b>S_SEND_WAIT</b><br>Espera puerto libre"]:::state
    
    SEND_WAIT --> IS_BUSY{"tx_busy == 0?"}:::decision
    IS_BUSY -- No --> SEND_WAIT
    
    IS_BUSY -- Sí --> SEND_BYTE["<b>S_SEND_BYTE</b><br>Transmite Byte (tx_start = 1)"]:::action
    SEND_BYTE --> WAIT_BUSY{"tx_busy == 1?"}:::decision
    
    WAIT_BUSY -- No --> WAIT_BUSY
    WAIT_BUSY -- Sí --> CHECK_TX_CNT{"tx_cnt == 8?"}:::decision
    
    CHECK_TX_CNT -- No (Siguiente Byte) --> INC_CNT["tx_cnt++"]:::action
    INC_CNT --> SEND_WAIT
    
    CHECK_TX_CNT -- Sí (Fin de Trama) --> DONE["<b>S_DONE</b><br>Transmisión Finalizada"]:::action
    DONE --> IDLE
```
