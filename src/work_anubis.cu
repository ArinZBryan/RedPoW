#include <work_anubis.h>

#include <cuda/std/span>
#include <cuda/std/cstring>
#include <cuda/std/array>

#include <vendor/bitcoin/crypto/sha256.h>

#include <sha256.cuh>
#include <utility.cuh>
#include <device_bitmanip.cuh>

__host__ __device__ uint hash_countl_zero(cuda::std::span<const uint32_t, 8> hash) {
    uint total_zeroes = 0;
    constexpr int bits_per_chunk = 64;

    for (int i = 0; i < 4; i++) {
        uint64_t chunk = 0;

        // apparently this gets optimised away into a register load because its small
        // which prevents c++ UB due to an unaligned pointer having strict aliasing issues
        chunk = (static_cast<uint64_t>(hash[i * 2]) << 32) | hash[i * 2 + 1]; // word 0 is the most significant

        uint zeroes = cuda::std::countl_zero(chunk);
        total_zeroes += zeroes;

        if (zeroes < bits_per_chunk) break;
    }

    return total_zeroes;
}

uint hash_countl_zero(cuda::std::span<const uint8_t, 32> hash) {
    uint total_zeroes = 0;
    constexpr int bits_per_chunk = 64;

    for (int i = 0; i < 4; i++) {
        uint64_t chunk = 0;

        // apparently this gets optimised away into a register load because its small
        // which prevents c++ UB due to an unaligned pointer having strict aliasing issues
        cuda::std::memcpy(&chunk, &hash[i * 8], sizeof(uint64_t));
        chunk = __builtin_bswap64(chunk); // hash bytes are big-endian; make byte 0 the most significant

        uint zeroes = cuda::std::countl_zero(chunk);
        total_zeroes += zeroes;

        if (zeroes < bits_per_chunk) break;
    }

    return total_zeroes;
}

__device__ bool d_unit_of_work_js(cuda::std::span<const uint8_t> remaining_seed, uint64_t nonce, struct sha256state& partial_state, size_t bits_hashed_so_far, uint difficulty) {
    
    // the nonce is appended to the seed as ASCII decimal digits (matches poc.py: seed + str(i))
    constexpr size_t max_nonce_digits = 20; // digits in UINT64_MAX
    constexpr size_t max_remaining_seed = 64; // seed bytes left over after the full chunks were hashed
    assert(remaining_seed.size() <= max_remaining_seed);

    cuda::std::array<uint8_t, max_remaining_seed + max_nonce_digits> msg;
    cuda::std::memcpy(msg.data(), remaining_seed.data(), remaining_seed.size());

    size_t digits = 1;
    for (uint64_t n = nonce; n >= 10; n /= 10) digits++;

    uint64_t n = nonce;
    for (size_t i = digits; i-- > 0;) {
        msg[remaining_seed.size() + i] = static_cast<uint8_t>('0' + n % 10);
        n /= 10;
    }

    const struct sha256state result = sha256partial(
        cuda::std::span<const uint8_t>(msg.data(), remaining_seed.size() + digits),
        partial_state,
        bits_hashed_so_far
    );

    const cuda::std::array<uint32_t, 8> words = {
        result.a, result.b, result.c, result.d, result.e, result.f, result.g, result.h
    };

    return hash_countl_zero(cuda::std::span<const uint32_t, 8>(words)) >= difficulty;
}

__device__ bool d_unit_of_work_wasm(cuda::std::span<const uint8_t> remaining_seed, uint32_t nonce, struct sha256state& partial_state, size_t bits_hashed_so_far, uint difficulty, bool nonce_is_little_endian) {
    
    // the nonce is appended to the seed as ASCII decimal digits (matches poc.py: seed + str(i))
    constexpr size_t max_nonce_digits = 20; // digits in UINT64_MAX
    constexpr size_t max_remaining_seed = 64; // seed bytes left over after the full chunks were hashed
    assert(remaining_seed.size() <= max_remaining_seed);

    cuda::std::array<uint8_t, max_remaining_seed + max_nonce_digits> msg;
    cuda::std::memcpy(msg.data(), remaining_seed.data(), remaining_seed.size());

    size_t digits = 1;
    for (uint64_t n = nonce; n >= 10; n /= 10) digits++;

    uint32_t nonce_bits = nonce_is_little_endian ? nonce : swap_endianness(nonce);
    cuda::std::memcpy(&msg[remaining_seed.size()], &nonce_bits, sizeof(uint32_t));
    
    const struct sha256state result = sha256partial(
        cuda::std::span<const uint8_t>(msg.data(), remaining_seed.size() + digits),
        partial_state,
        bits_hashed_so_far
    );

    const cuda::std::array<uint32_t, 8> words = {
        result.a, result.b, result.c, result.d, result.e, result.f, result.g, result.h
    };

    return hash_countl_zero(cuda::std::span<const uint32_t, 8>(words)) >= difficulty;
}

__global__ void k_work_js(
    cuda::std::span<const uint8_t> d_remaining_seed, 
    uint64_t d_num_nonces, 
    struct sha256state* d_partial_state, 
    size_t d_bits_hashed_so_far, 
    uint d_difficulty, 
    int* d_found_flag,
    uint64_t* d_found_nonce
) {
    size_t thread_id = THREAD_ID_1D;
    size_t stride = THREAD_COUNT_IN_GRID_1D;

    for (uint64_t nonce = thread_id; nonce < d_num_nonces; nonce += stride) {
        if (__ldcg(d_found_flag)) { // the __ldcg intrinsic generates a load that bypasses the L1 cache, and prevents stale values from being read.
            return;
        }
        
        if (d_unit_of_work_js(d_remaining_seed, nonce, *d_partial_state, d_bits_hashed_so_far, d_difficulty)) {
            int someones_already_found_it = atomicCAS(d_found_flag, false, true);
            if (!someones_already_found_it) {
                *d_found_nonce = nonce;
            }
            return;
        }
    }
}


__global__ void k_work_wasm(
    cuda::std::span<const uint8_t> d_remaining_seed, 
    uint32_t d_num_nonces, 
    struct sha256state* d_partial_state, 
    size_t d_bits_hashed_so_far, 
    uint d_difficulty, 
    bool d_nonce_is_little_endian,
    int* d_found_flag,
    uint64_t* d_found_nonce
) {
    size_t thread_id = THREAD_ID_1D;
    size_t stride = THREAD_COUNT_IN_GRID_1D;

    for (uint32_t nonce = thread_id; nonce < d_num_nonces; nonce += stride) {
        if (__ldcg(d_found_flag)) { // the __ldcg intrinsic generates a load that bypasses the L1 cache, and prevents stale values from being read.
            return;
        }
        
        if (d_unit_of_work_wasm(d_remaining_seed, nonce, *d_partial_state, d_bits_hashed_so_far, d_difficulty, d_nonce_is_little_endian)) {
            int someones_already_found_it = atomicCAS(d_found_flag, false, true);
            if (!someones_already_found_it) {
                *d_found_nonce = nonce;
            }
            return;
        }
    }
}

std::optional<uint64_t> do_anubis_js_singlethreaded_cpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty) {
    size_t seed_byte_length = seed.end() - seed.begin();
    
    size_t n_full_chunks = seed_byte_length / 64;
    size_t bytes_in_last_chunk = seed_byte_length % 64;

    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), n_full_chunks * 64);
    CSHA256 saved_state = hasher;

    unsigned char hash[32] = {0};

    for (uint64_t nonce = 0; nonce < nonce_max; nonce++) {
        hasher = saved_state;
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data() + n_full_chunks * 64), bytes_in_last_chunk);
        
        cuda::std::array<uint8_t, 20> digitbuf = cuda::std::array<uint8_t, 20>();

        size_t digits = 1;
        for (uint64_t n = nonce; n >= 10; n /= 10) digits++;

        uint64_t n = nonce;
        for (size_t i = digits; i-- > 0;) {
            digitbuf[i] = static_cast<uint8_t>('0' + n % 10);
            n /= 10;
        }
        hasher.Write(digitbuf.data(), digits);

        hasher.Finalize(hash);
        if (hash_countl_zero(hash) >= difficulty) {
            return nonce;
        }
    }

    return std::nullopt;
}

std::optional<uint64_t> do_anubis_js_gpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty) {
    size_t seed_byte_length = seed.end() - seed.begin();
    
    size_t n_full_chunks = seed_byte_length / 64;
    size_t bytes_in_last_chunk = seed_byte_length % 64;

    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), n_full_chunks * 64);
    uint8_t* d_remaining_seed_buf = nullptr;
    cudaMallocManaged(&d_remaining_seed_buf, sizeof(uint8_t) * bytes_in_last_chunk);
    cuda::std::memcpy(d_remaining_seed_buf, seed.data() + n_full_chunks * 64, bytes_in_last_chunk);
    auto d_remaining_seed = cuda::std::span<const uint8_t>(d_remaining_seed_buf, bytes_in_last_chunk); 
    

    struct sha256state* d_partial_state = nullptr;
    cudaMallocManaged(&d_partial_state, sizeof(struct sha256state));
    cuda::std::memcpy(d_partial_state, &hasher.s, sizeof(struct sha256state));

    int* d_found_flag = nullptr;
    cudaMallocManaged(&d_found_flag, sizeof(int));
    *d_found_flag = 0;

    uint64_t* d_found_nonce = nullptr;
    cudaMallocManaged(&d_found_nonce, sizeof(uint64_t));

    auto[gridSize, blockSize] = getBestBigKernelLaunchParams(k_work_js);

    k_work_js<<<gridSize, blockSize>>>(
        d_remaining_seed,
        nonce_max,
        d_partial_state,
        n_full_chunks * 64 * 8,
        difficulty,
        d_found_flag,
        d_found_nonce
    );

    cudaDeviceSynchronize();

    std::optional<uint64_t> result = std::nullopt;
    if (*d_found_flag) {
        result = *d_found_nonce;
    }

    cudaFree(d_remaining_seed_buf);
    cudaFree(d_partial_state);
    cudaFree(d_found_flag);
    cudaFree(d_found_nonce);

    return result;
}

std::optional<uint64_t> do_anubis_wasm_singlethreaded_cpu(const std::span<uint8_t>& seed, uint32_t nonce_max, uint32_t difficulty) {
    size_t seed_byte_length = seed.end() - seed.begin();
    bool nonce_is_little_endian = seed[seed.size() - 1] >= 128;
    size_t n_full_chunks = seed_byte_length / 64;
    size_t bytes_in_last_chunk = seed_byte_length % 64;

    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), n_full_chunks * 64);
    CSHA256 saved_state = hasher;

    unsigned char hash[32] = {0};

    for (uint32_t nonce = 0; nonce < nonce_max; nonce++) {
        hasher = saved_state;
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data() + n_full_chunks * 64), bytes_in_last_chunk);

        uint32_t nonce_bits = nonce_is_little_endian ? nonce : swap_endianness(nonce);
        hasher.Write(reinterpret_cast<const unsigned char*>(&nonce_bits), sizeof(uint32_t));

        hasher.Finalize(hash);
        if (hash_countl_zero(hash) >= difficulty) {
            return nonce;
        }
    }

    return std::nullopt;
}

std::optional<uint64_t> do_anubis_wasm_gpu(const std::span<uint8_t>& seed, uint32_t nonce_max, uint32_t difficulty) {
    size_t seed_byte_length = seed.end() - seed.begin();
    bool nonce_is_little_endian = seed[seed.size() - 1] >= 128;

    size_t n_full_chunks = seed_byte_length / 64;
    size_t bytes_in_last_chunk = seed_byte_length % 64;

    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), n_full_chunks * 64);
    uint8_t* d_remaining_seed_buf = nullptr;
    cudaMallocManaged(&d_remaining_seed_buf, sizeof(uint8_t) * bytes_in_last_chunk);
    cuda::std::memcpy(d_remaining_seed_buf, seed.data() + n_full_chunks * 64, bytes_in_last_chunk);
    auto d_remaining_seed = cuda::std::span<const uint8_t>(d_remaining_seed_buf, bytes_in_last_chunk); 
    

    struct sha256state* d_partial_state = nullptr;
    cudaMallocManaged(&d_partial_state, sizeof(struct sha256state));
    cuda::std::memcpy(d_partial_state, &hasher.s, sizeof(struct sha256state));

    int* d_found_flag = nullptr;
    cudaMallocManaged(&d_found_flag, sizeof(int));
    *d_found_flag = 0;

    uint64_t* d_found_nonce = nullptr;
    cudaMallocManaged(&d_found_nonce, sizeof(uint64_t));

    auto[gridSize, blockSize] = getBestBigKernelLaunchParams(k_work_js);

    k_work_wasm<<<gridSize, blockSize>>>(
        d_remaining_seed,
        nonce_max,
        d_partial_state,
        n_full_chunks * 64 * 8,
        difficulty,
        nonce_is_little_endian,
        d_found_flag,
        d_found_nonce
    );

    cudaDeviceSynchronize();

    std::optional<uint64_t> result = std::nullopt;
    if (*d_found_flag) {
        result = *d_found_nonce;
    }

    cudaFree(d_remaining_seed_buf);
    cudaFree(d_partial_state);
    cudaFree(d_found_flag);
    cudaFree(d_found_nonce);

    return result;
}