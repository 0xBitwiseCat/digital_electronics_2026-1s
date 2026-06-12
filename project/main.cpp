#include <iostream>
#include <cstdint>
#include <iomanip>

// S-Box estándar de PRESENT (Tabla 1 del paper)
const uint8_t SBOX[16] = {
    0xC, 0x5, 0x6, 0xB, 0x9, 0x0, 0xA, 0xD, 
    0x3, 0xE, 0xF, 0x8, 0x4, 0x7, 0x1, 0x2
};

// Función para generar las 32 subllaves de ronda a partir de la llave de 80 bits.
// Para el manejo eficiente de 80 bits en C++, dividimos la llave en dos partes:
// key_high (16 bits más significativos) y key_low (64 bits menos significativos).
void generate_round_keys(uint64_t key_high, uint64_t key_low, uint64_t round_keys[32]) {
    for (int i = 1; i <= 32; i++) {
        // La llave de ronda son los 64 bits más significativos del registro
        round_keys[i - 1] = (key_high << 48) | (key_low >> 16);
        
        // El registro de la llave se actualiza para la siguiente ronda (excepto en la 32)
        if (i < 32) {
            // 1. Shift circular a la izquierda por 61 posiciones (equivalente a derecha por 19)
            uint64_t old_high = key_high & 0xFFFF;
            uint64_t old_low = key_low;
            
            uint64_t new_low = (old_low >> 19) | (old_high << 45) | ((old_low & 0x7) << 61);
            uint64_t new_high = (old_low >> 3) & 0xFFFF;
            
            key_low = new_low;
            key_high = new_high;
            
            // 2. Pasar los 4 bits más significativos por la S-Box
            uint8_t sbox_in = key_high >> 12;
            uint8_t sbox_out = SBOX[sbox_in];
            key_high = (key_high & 0x0FFF) | ((uint64_t)sbox_out << 12);
            
            // 3. Hacer XOR del contador de ronda con los bits k_19 ... k_15
            key_low ^= ((uint64_t)i << 15);
        }
    }
}

// Función principal de encriptación
uint64_t present_encrypt(uint64_t plaintext, const uint64_t round_keys[32]) {
    uint64_t state = plaintext;
    
    // El cifrador tiene 31 rondas completas
    for (int i = 0; i < 31; i++) {
        // 1. addRoundKey
        state ^= round_keys[i];
        
        // 2. sBoxLayer: Se aplica la S-box 16 veces en paralelo sobre nibbles de 4 bits
        uint64_t next_state_s = 0;
        for (int j = 0; j < 16; j++) {
            uint8_t nibble = (state >> (j * 4)) & 0xF;
            next_state_s |= ((uint64_t)SBOX[nibble] << (j * 4));
        }
        state = next_state_s;
        
        // 3. pLayer: Permutación a nivel de bits
        uint64_t next_state_p = 0;
        for (int j = 0; j < 64; j++) {
            // La posición matemática descrita P(i)
            int p = (j == 63) ? 63 : (16 * j) % 63;
            if ((state >> j) & 1) {
                next_state_p |= (1ULL << p);
            }
        }
        state = next_state_p;
    }
    
    // Post-whitening: addRoundKey con la subllave 32
    state ^= round_keys[31];
    
    return state;
}

// Función auxiliar para imprimir y validar los resultados
void test_present(uint64_t key_high, uint64_t key_low, uint64_t pt, uint64_t expected_ct) {
    uint64_t round_keys[32];
    generate_round_keys(key_high, key_low, round_keys);
    uint64_t ct = present_encrypt(pt, round_keys);
    
    std::cout << std::hex << std::uppercase << std::setfill('0');
    std::cout << "Llave: " << std::setw(4) << key_high << std::setw(16) << key_low 
              << " | Texto Plano: " << std::setw(16) << pt 
              << " | Cifrado: " << std::setw(16) << ct;
              
    if (ct == expected_ct) {
        std::cout << "  [EXITO]\n";
    } else {
        std::cout << "  [FALLO] Esperado: " << expected_ct << "\n";
    }
}

int main() {
    std::cout << "=== Vectores de Prueba Oficiales para PRESENT-80 ===\n";
    
    // Caso 1: Llave en 0, Texto en 0
    test_present(0x0000, 0x0000000000000000ULL, 0x0000000000000000ULL, 0x5579C1387B228445ULL);
    
    // Caso 2: Llave en 0, Texto en F's
    test_present(0x0000, 0x0000000000000000ULL, 0xFFFFFFFFFFFFFFFFULL, 0xA112FFC72F68417BULL);
    
    // Caso 3: Llave en F's, Texto en 0
    test_present(0xFFFF, 0xFFFFFFFFFFFFFFFFULL, 0x0000000000000000ULL, 0xE72C46C0F5945049ULL);
    
    // Caso 4: Llave en F's, Texto en F's
    test_present(0xFFFF, 0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL, 0x3333DCD3213210D2ULL);
    
    return 0;
}
