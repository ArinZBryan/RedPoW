#include <span>
#include <cstdint>
#include <cstdlib>
#include <cstring>

uint hash_countl_zero(std::span<const uint8_t, 32> hash) {
    uint total_zeroes = 0;
    constexpr int bits_per_chunk = 64;

    for (int i = 0; i < 4; i++) {
        uint64_t chunk = 0;

        // apparently this gets optimised away into a register load because its small
        // which prevents c++ UB due to an unaligned pointer having strict aliasing issues
        std::memcpy(&chunk, &hash[i * 8], sizeof(uint64_t));
        chunk = __builtin_bswap64(chunk); // hash bytes are big-endian; make byte 0 the most significant

        uint zeroes = std::countl_zero(chunk);
        total_zeroes += zeroes;

        if (zeroes < bits_per_chunk) break;
    }

    return total_zeroes;
}
