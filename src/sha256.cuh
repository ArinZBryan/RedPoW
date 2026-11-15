#pragma once
#include <utility.cuh>
#include <device_bitmanip.cuh>
#include <cuda/std/array>
#include <cuda/std/span>
#include <cuda/std/mdspan>
#include <cuda/std/cmath>
#include <cassert>
#include <cstdint>
#include <cassert>

struct sha256state {
    uint32_t a, b, c, d, e, f, g, h;  
};

inline __constant__ struct sha256state initial_hash_state = {
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19
};


inline __constant__ uint32_t k[] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

inline __device__ void sha256_chunk(struct sha256state& s, cuda::std::span<uint32_t, 16> w) {
    uint32_t a = s.a;
    uint32_t b = s.b;
    uint32_t c = s.c;
    uint32_t d = s.d;
    uint32_t e = s.e;
    uint32_t f = s.f;
    uint32_t g = s.g;
    uint32_t h = s.h;


    #pragma unroll
    for (int i = 0; i < 64; i++) {
        if (i >= 16) { //need to perform circular replacement
            const uint32_t w15 = w[(i - 15) & 15];
            const uint32_t w2 = w[(i - 2) & 15];

            const uint32_t s0 = rotr(w15, 7) ^ rotr(w15, 18) ^ (w15 >> 3);
            const uint32_t s1 = rotr(w2, 17) ^ rotr(w2, 19) ^ (w2 >> 10);
            
            w[i & 15] += s0 + w[(i - 7) & 15] + s1;   // w[i & 15] currently holds w[i-16]
        }
        
        const uint32_t S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        const uint32_t ch = (e & f) ^ (~e & g);
        const uint32_t temp1 = h + S1 + ch + k[i] + w[i & 15];
        const uint32_t S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        const uint32_t temp2 = S0 + maj;

        h = g; 
        g = f; 
        f = e; 
        e = d + temp1;
        d = c;  
        c = b;
        b = a; 
        a = temp1 + temp2;
    }

    s.a += a;
    s.b += b;
    s.c += c;
    s.d += d;
    s.e += e;
    s.f += f;
    s.g += g;
    s.h += h;
}



template <size_t MessageLen>
__device__ struct sha256state sha256(cuda::std::span<const uint8_t, MessageLen> msg) {
    constexpr size_t n_full_chunks = MessageLen / 64;
    constexpr size_t bytes_in_last_chunk = MessageLen % 64;
    constexpr size_t last_chunk_buffer_multiple = (bytes_in_last_chunk + 9) <= 64 ? 1 : 2;
    constexpr uint64_t msg_size_bits = static_cast<uint64_t>(MessageLen) * 8;

    struct sha256state s = initial_hash_state;
    
    cuda::std::array<uint32_t, 16> W_circular;
    
    for (int chunk = 0; chunk < n_full_chunks; chunk++) {
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&msg[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    cuda::std::array<uint8_t, last_chunk_buffer_multiple * 64> last_chunk_buffer = {0};
    #pragma unroll
    for (size_t i = 0; i < bytes_in_last_chunk; i++) { last_chunk_buffer[i] = msg[n_full_chunks * 64 + i]; }
    last_chunk_buffer[bytes_in_last_chunk] = 0x80;
    #pragma unroll
    for (int i = 0; i < 8; i++) { last_chunk_buffer[last_chunk_buffer.size() - 1 - i] = static_cast<uint8_t>(msg_size_bits >> (8 * i)); }

    #pragma unroll
    for (int chunk = 0; chunk < last_chunk_buffer_multiple; chunk++) {
        #pragma unroll
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&last_chunk_buffer[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    return s;
}

template <size_t MessageLen>
__device__ struct sha256state sha256partial(cuda::std::span<const uint8_t, MessageLen> msg, struct sha256state current_state, size_t bits_hashed_so_far) {
    constexpr size_t n_full_chunks = MessageLen / 64;
    constexpr size_t bytes_in_last_chunk = MessageLen % 64;
    constexpr size_t last_chunk_buffer_multiple = (bytes_in_last_chunk + 9) <= 64 ? 1 : 2;
    uint64_t msg_size_bits = bits_hashed_so_far + static_cast<uint64_t>(MessageLen) * 8;

    struct sha256state s = current_state;

    cuda::std::array<uint32_t, 16> W_circular;
    
    for (int chunk = 0; chunk < n_full_chunks; chunk++) {
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&msg[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    cuda::std::array<uint8_t, last_chunk_buffer_multiple * 64> last_chunk_buffer = {0};
    #pragma unroll
    for (size_t i = 0; i < bytes_in_last_chunk; i++) { last_chunk_buffer[i] = msg[n_full_chunks * 64 + i]; }
    last_chunk_buffer[bytes_in_last_chunk] = 0x80;
    #pragma unroll
    for (int i = 0; i < 8; i++) { last_chunk_buffer[last_chunk_buffer.size() - 1 - i] = static_cast<uint8_t>(msg_size_bits >> (8 * i)); }

    #pragma unroll
    for (int chunk = 0; chunk < last_chunk_buffer_multiple; chunk++) {
        #pragma unroll
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&last_chunk_buffer[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    return s;
}

inline __device__ struct sha256state sha256partial(cuda::std::span<const uint8_t> msg, struct sha256state current_state, size_t bits_hashed_so_far) {
    size_t n_full_chunks = msg.size_bytes() / 64;
    size_t bytes_in_last_chunk = msg.size_bytes() % 64;
    size_t last_chunk_buffer_multiple = (bytes_in_last_chunk + 9) <= 64 ? 1 : 2;
    uint64_t msg_size_bits = bits_hashed_so_far + static_cast<uint64_t>(msg.size_bytes()) * 8;

    struct sha256state s = current_state;

    cuda::std::array<uint32_t, 16> W_circular;
    
    for (int chunk = 0; chunk < n_full_chunks; chunk++) {
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&msg[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    cuda::std::array<uint8_t, 128> last_chunk_buffer = {0};
    #pragma unroll
    for (size_t i = 0; i < bytes_in_last_chunk; i++) { last_chunk_buffer[i] = msg[n_full_chunks * 64 + i]; }
    last_chunk_buffer[bytes_in_last_chunk] = 0x80;
    // the buffer is sized for the worst case, so the length must go at the end of the chunks actually hashed, not the end of the buffer
    #pragma unroll
    for (int i = 0; i < 8; i++) { last_chunk_buffer[last_chunk_buffer_multiple * 64 - 1 - i] = static_cast<uint8_t>(msg_size_bits >> (8 * i)); }

    #pragma unroll
    for (int chunk = 0; chunk < last_chunk_buffer_multiple; chunk++) {
        #pragma unroll
        for (size_t chunk_words = 0; chunk_words < 16; chunk_words++) {
            W_circular[chunk_words] = swap_endianness(*(reinterpret_cast<const uint32_t*>(&last_chunk_buffer[chunk * 64 + chunk_words * sizeof(uint32_t)])));
        }
        sha256_chunk(s, W_circular);
    }

    return s;
}

template <size_t MessageLen>
__global__ void sha256_hash(cuda::std::span<const cuda::std::span<uint8_t, MessageLen>> msgs, cuda::std::span<struct sha256state> out) {
    assert(out.size() == msgs.size());
    
    size_t thread_index = THREAD_ID_1D;
    size_t thread_count = THREAD_COUNT_1D;

    uint work_per_thread = static_cast<uint>(ceilf(static_cast<float>(out.size()) / static_cast<float>(thread_count)));

    for (uint i = 0; i < work_per_thread; i++) {
        size_t idx = i * thread_count + thread_index;
        if (idx < out.size()) {
            out[idx] = sha256<MessageLen>(msgs[idx]);
        }
    }
}

template <size_t MessageLen>
__global__ void sha256_hash(
    cuda::std::mdspan<const std::uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, MessageLen>> msgs, cuda::std::span<struct sha256state> out) {
    assert(out.size() == msgs.extent(0));

    for (size_t idx = THREAD_ID_1D; idx < out.size(); idx += THREAD_COUNT_1D) {
        cuda::std::span<const std::uint8_t, MessageLen> msg(&msgs(idx, 0), MessageLen);
        
        out[idx] = sha256<MessageLen>(msg);
    }
}

template <size_t MessageLen>
__global__ void sha256_hash_partial(cuda::std::mdspan<const uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, MessageLen>> msgs, cuda::std::span<struct sha256state> partial_states, size_t bits_hashed_so_far) {
    assert(partial_states.size() == msgs.extent(0));

    for (size_t idx = THREAD_ID_1D; idx < partial_states.size(); idx += THREAD_COUNT_1D) {
        cuda::std::span<const std::uint8_t, MessageLen> msg(&msgs(idx, 0), MessageLen);
        
        partial_states[idx] = sha256partial<MessageLen>(msg, partial_states[idx], bits_hashed_so_far);
    }
}

