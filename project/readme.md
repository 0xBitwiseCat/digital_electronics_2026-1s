# Digital Electronics I - Final project
## Implementation of a lightweight cryptography algorithm for low-capacity IoT devices 

### FSM
The following diagram represents algorithm-flow using a finite state machine for PRESENT-80

```mermaid
stateDiagram-v2
    direction TB
    
    %% Definición de los nodos (Estados)
    state "ST_IDLE (000)
          Reposo" as IDLE
    state "ST_LOAD (001)
          Carga Inicial" as LOAD
    state "ST_ROUND_OP (010)
          Bucle de 31 Rondas" as ROUND_OP
    state "ST_FINAL_XOR (011)
          Post-blanqueo" as FINAL_XOR
    state "ST_DONE (100)
          Fin de Cifrado" as DONE
    state "ST_STANDBY (101)
          Espera (Wait for Start=0)" as STANDBY

    %% Transiciones
    [*] --> IDLE : rst = 1
    
    IDLE --> LOAD : start == 1
    
    LOAD --> ROUND_OP : Siguiente reloj (load_key = 1)
    
    ROUND_OP --> ROUND_OP : round_counter < 31 (update_key = 1)
    
    ROUND_OP --> FINAL_XOR : round_counter == 31 (update_key = 1)
    
    FINAL_XOR --> DONE : Siguiente reloj
    
    DONE --> STANDBY : Siguiente reloj (Genera pulso done = 1)
    
    STANDBY --> STANDBY : start == 1 (done = 0)

    STANDBY --> IDLE : start == 0
```

> [!NOTE]
> Each step has its own functionality implement by the modules in this repo.
