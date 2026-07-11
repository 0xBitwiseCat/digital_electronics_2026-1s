import serial
import serial.tools.list_ports
import time
import struct

# =======================================================================
# 1. MODELO DE REFERENCIA EN SOFTWARE (PRESENT-80)
# =======================================================================
def present_80_encrypt(plaintext: int, key: int) -> int:
    SBOX = [0xC, 0x5, 0x6, 0xB, 0x9, 0x0, 0xA, 0xD, 0x3, 0xE, 0xF, 0x8, 0x4, 0x7, 0x1, 0x2]
    PBOX = [(i * 16) % 63 if i < 63 else 63 for i in range(64)]
    
    state = plaintext
    k = key
    
    for round_num in range(1, 32):
        # AddRoundKey
        round_key = k >> 16
        state ^= round_key
        
        # sBoxLayer
        new_state = 0
        for i in range(16):
            nibble = (state >> (i * 4)) & 0xF
            new_state |= (SBOX[nibble] << (i * 4))
        state = new_state
        
        # pLayer
        new_state = 0
        for i in range(64):
            bit = (state >> i) & 1
            new_state |= (bit << PBOX[i])
        state = new_state
        
        # Key Schedule Update
        k = ((k & ((1 << 19) - 1)) << 61) | (k >> 19)
        sbox_in = k >> 76
        k = (SBOX[sbox_in] << 76) | (k & 0x0FFFFFFFFFFFFFFFFFFF)
        k ^= (round_num << 15)
        
    # Post-whitening
    state ^= (k >> 16)
    return state

# =======================================================================
# 2. CÁLCULO DE CRC-8 (Polinomio 0x07)
# =======================================================================
def crc8(data_bytes: bytes) -> int:
    crc = 0x00
    for b in data_bytes:
        crc ^= b
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ 0x07) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc

# =======================================================================
# 3. INTERFAZ Y ORQUESTACIÓN SERIAL (VERSIÓN WINDOWS)
# =======================================================================
def seleccionar_puerto_com():
    """Detecta y permite al usuario elegir el puerto COM en Windows."""
    puertos = list(serial.tools.list_ports.comports())
    if not puertos:
        print("[ERROR] No se detectaron puertos COM. Verifica que la FPGA esté conectada.")
        return None
        
    print("\nPuertos COM disponibles:")
    for i, p in enumerate(puertos):
        print(f" [{i}] {p.device} - {p.description}")
        
    while True:
        seleccion = input("\nSelecciona el número del puerto de la FPGA: ")
        try:
            indice = int(seleccion)
            if 0 <= indice < len(puertos):
                return puertos[indice].device
            else:
                print("Número fuera de rango.")
        except ValueError:
            print("Por favor, ingresa un número válido.")

def ejecutar_vectores_de_prueba(ser):
    """Ejecuta automáticamente los vectores de prueba del paper oficial de PRESENT."""
    print("\n" + "="*50)
    print("🚀 EJECUTANDO VECTORES DE PRUEBA OFICIALES (PAPER)")
    print("="*50)
    
    vectores = [
        {"pt": "0000000000000000", "key": "00000000000000000000", "ct": "5579C1387B228445"},
        {"pt": "0000000000000000", "key": "FFFFFFFFFFFFFFFFFFFF", "ct": "E72C46C0F5945049"},
        {"pt": "FFFFFFFFFFFFFFFF", "key": "00000000000000000000", "ct": "A112FFC72F68417B"},
        {"pt": "FFFFFFFFFFFFFFFF", "key": "FFFFFFFFFFFFFFFFFFFF", "ct": "3333DCD3213210D2"}
    ]
    
    for idx, vec in enumerate(vectores):
        print(f"\n--- Test Vector {idx + 1} ---")
        pt_bytes = bytes.fromhex(vec["pt"])
        key_bytes = bytes.fromhex(vec["key"])
        
        # Preparar trama
        trama_tx = pt_bytes + key_bytes
        tx_crc = crc8(trama_tx)
        trama_tx_completa = trama_tx + bytes([tx_crc])
        
        # Enviar y medir tiempo
        t0 = time.perf_counter()
        ser.write(trama_tx_completa)
        respuesta = ser.read(9)
        t1 = time.perf_counter()
        
        if len(respuesta) != 9:
            print("[ERROR] Timeout en FPGA durante el test.")
            continue
            
        fpga_cipher_hex = respuesta[:8].hex().upper()
        
        print(f"PT (Hex)       : {vec['pt']}")
        print(f"Key (Hex)      : {vec['key']}")
        print(f"CT Esperado    : {vec['ct']}")
        print(f"CT FPGA        : {fpga_cipher_hex}")
        print(f"Tiempo Tx/Rx   : {(t1 - t0) * 1000:.2f} ms")
        
        if fpga_cipher_hex == vec["ct"]:
            print("[ESTADO] ✅ TEST SUPERADO")
        else:
            print("[ESTADO] ❌ TEST FALLIDO")
            
    print("="*50 + "\n")

def main():
    print("=== ORQUESTADOR PRESENT-80 (WINDOWS) ===")
    
    # Detección del puerto COM
    puerto_com = seleccionar_puerto_com()
    if not puerto_com:
        return
        
    BAUD_RATE = 9600
    
    # Inicialización del puerto serial
    try:
        ser = serial.Serial(puerto_com, BAUD_RATE, timeout=2.0)
        time.sleep(2) # Tiempo de estabilización del buffer serial en Windows
    except Exception as e:
        print(f"Error al abrir el puerto {puerto_com}: {e}")
        return

    # 1. Ejecutar casos del paper automáticamente
    ejecutar_vectores_de_prueba(ser)

    # 2. Bucle para modo manual del usuario
    while True:
        print("\n--- MODO ENCRIPTACIÓN MANUAL ---")
        key_hex = input("Ingresa la llave de 80 bits en hexadecimal (o 'q' para salir):\n> ").strip()
        
        if key_hex.lower() == 'q':
            break
            
        if len(key_hex) != 20:
            print("Error: La llave debe tener exactamente 20 caracteres hexadecimales (80 bits).")
            continue
            
        key_int = int(key_hex, 16)
        key_bytes = key_int.to_bytes(10, byteorder='big')
        
        mensaje = input("Ingresa el mensaje a cifrar:\n> ")
        
        # Padding a 64 bits
        mensaje_bytes = mensaje.encode('utf-8')
        padding_len = (8 - (len(mensaje_bytes) % 8)) % 8
        mensaje_bytes += b' ' * padding_len
        
        chunks = [mensaje_bytes[i:i+8] for i in range(0, len(mensaje_bytes), 8)]
        print(f"\n[INFO] Mensaje dividido en {len(chunks)} bloques de 64 bits.")
        
        # Procesamiento por Chunks
        for idx, chunk in enumerate(chunks):
            print(f"\n--- Procesando Bloque {idx + 1}/{len(chunks)} ---")
            print(f"Texto del bloque   : '{chunk.decode('utf-8')}'")
            
            trama_tx = chunk + key_bytes
            tx_crc = crc8(trama_tx)
            trama_tx_completa = trama_tx + bytes([tx_crc])
            
            plaintext_int = int.from_bytes(chunk, byteorder='big')
            expected_cipher_int = present_80_encrypt(plaintext_int, key_int)
            expected_cipher_hex = f"{expected_cipher_int:016X}"
            
            print(f"Esperado (Software): 0x{expected_cipher_hex}")
            
            # MEDICIÓN DE TIEMPO DE COMUNICACIÓN
            t0 = time.perf_counter()
            ser.write(trama_tx_completa)
            respuesta = ser.read(9)
            t1 = time.perf_counter()
            
            if len(respuesta) != 9:
                print("[ERROR] Timeout. No se recibió respuesta completa de la FPGA.")
                continue
                
            fpga_cipher_bytes = respuesta[:8]
            fpga_crc = respuesta[8]
            
            calc_rx_crc = crc8(fpga_cipher_bytes)
            if calc_rx_crc != fpga_crc:
                print(f"[ALERTA] Fallo de integridad CRC. Calculado: {hex(calc_rx_crc)}, Recibido: {hex(fpga_crc)}")
            
            fpga_cipher_hex = fpga_cipher_bytes.hex().upper()
            
            print(f"Recibido (FPGA)    : 0x{fpga_cipher_hex}")
            print(f"Tiempo CPU (Tx/Rx) : {(t1 - t0) * 1000:.2f} milisegundos")
            
            if fpga_cipher_hex == expected_cipher_hex:
                print("[ESTADO] ✅ ENCRIPTACIÓN CORRECTA")
            else:
                print("[ESTADO] ❌ ERROR: Los resultados no coinciden")

    ser.close()
    print("\n=== TRANSMISIÓN FINALIZADA ===")

if __name__ == "__main__":
    main()