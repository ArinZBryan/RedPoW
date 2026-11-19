#include <work_mcaptcha.h>

#include <cuda/std/span>
#include <cuda/std/cstring>
#include <cuda/std/array>
#include <cuda/std/limits>

#include <cassert>

#include <vendor/bitcoin/crypto/sha256.h>

#include <sha256.cuh>
#include <utility.cuh>


constexpr __uint128_t uint128_max = cuda::std::numeric_limits<__uint128_t>::max();

constexpr __uint128_t threshold(uint32_t difficultyFactor) {
	// "get_difficulty" in mcaptcha_pow_sha256; integer (floor) division
	return uint128_max - (uint128_max / difficultyFactor);
}

std::optional<mCaptchaResult> do_mCaptcha_singlethreaded_cpu(std::u8string_view salt, std::u8string_view phrase, uint32_t difficulty, uint64_t nonce_max) {
    assert(phrase.size() == 32);    // mCaptcha enforces that the phrase is a 32-character utf-8 alphanumeric string

    if (difficulty == 0) { return std::nullopt; }
    const size_t total_length = salt.size() + sizeof(uint64_t) + phrase.size();
    constexpr uint64_t phrase_length = 32;
    const __uint128_t target = threshold(difficulty);

    unsigned char hash[32] = {0};
    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(salt.data()), salt.size());
    hasher.Write(reinterpret_cast<const unsigned char*>(&phrase_length), sizeof(uint64_t));
    hasher.Write(reinterpret_cast<const unsigned char*>(phrase.data()), 32);
    CSHA256 saved_state = hasher;

    uint64_t nonce = 0;
    __uint128_t s = 0;
    for (nonce = 1; nonce != 0 && nonce <= nonce_max; nonce++) {
        hasher = saved_state;
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
        // the score is the first 16 bytes of the digest read as a big-endian integer
        s = 0;
        for (size_t i = 0; i < 16; i++) s = (s << 8) | hash[i];
        if (s >= target) {
            return mCaptchaResult{ nonce, s };
        }
    }
    return std::nullopt;
}

__device__ std::optional<__uint128_t> d_unit_of_work(cuda::std::span<const uint8_t> remaining_seed, uint64_t nonce, struct sha256state& partial_state, size_t bits_hashed_so_far, __uint128_t target) {
    // the nonce is appended to the seed as ASCII decimal digits (matches poc.py: seed + str(i))
    constexpr size_t max_nonce_digits = 20; // digits in UINT64_MAX
    constexpr size_t max_remaining_seed = 64; // seed bytes left over after the full chunks were hashed
    assert(remaining_seed.size() <= max_remaining_seed);

    cuda::std::array<uint8_t, max_remaining_seed + max_nonce_digits> msg;
    if (!remaining_seed.empty())
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

    /*const cuda::std::array<uint32_t, 8> words = {
        result.a, result.b, result.c, result.d, result.e, result.f, result.g, result.h
    };*/

    __uint128_t upper_bits = 0;
    // words is a big endian 256 bit number
    // convert the upper 128 bits to a little endian integer
    upper_bits =
        static_cast<__uint128_t>(result.d)       | 
        static_cast<__uint128_t>(result.c) << 32 | 
        static_cast<__uint128_t>(result.b) << 64 | 
        static_cast<__uint128_t>(result.a) << 96;

    if (upper_bits >= target /*&& upper_bits != static_cast<__uint128_t>(0)*/) {
        return upper_bits;
    }
    return std::nullopt;
}



__global__ void k_work(
    cuda::std::span<const uint8_t> d_remaining_seed, 
    uint64_t d_num_nonces, 
    struct sha256state* d_partial_state, 
    size_t d_bits_hashed_so_far, 
    __uint128_t d_target, 
    int* d_found_flag,
    struct mCaptchaResult* d_found_nonce
) {
    size_t thread_id = THREAD_ID_1D;
    size_t stride = THREAD_COUNT_IN_GRID_1D;

    for (uint64_t nonce = thread_id + 1; nonce <= d_num_nonces; nonce += stride) {
        if (__ldcg(d_found_flag)) { // the __ldcg intrinsic generates a load that bypasses the L1 cache, and prevents stale values from being read.
            return;
        }
        
        std::optional<__uint128_t> work_result = d_unit_of_work(d_remaining_seed, nonce, *d_partial_state, d_bits_hashed_so_far, d_target);
        if (work_result.has_value()) {
            int someones_already_found_it = atomicCAS(d_found_flag, false, true);
            if (!someones_already_found_it) {
                *d_found_nonce = mCaptchaResult{nonce, work_result.value()};
            }
            return;
        }
    }
}



std::optional<struct mCaptchaResult> do_mCaptcha_gpu(std::u8string_view salt, std::u8string_view phrase, uint32_t difficulty, uint64_t nonce_max) {
    assert(phrase.size() == 32);    // mCaptcha enforces that the phrase is a 32-character utf-8 alphanumeric string
    if (difficulty == 0) { return std::nullopt; }

    const size_t total_length = salt.size() + sizeof(uint64_t) + phrase.size();
    const size_t no_full_chunks = total_length / 64;
    const size_t bytes_in_last_chunk = total_length % 64;
    constexpr uint64_t phrase_length = 32; 
    const __uint128_t target = threshold(difficulty);

    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(salt.data()), salt.size());
    hasher.Write(reinterpret_cast<const unsigned char*>(&phrase_length), sizeof(uint64_t));
    hasher.Write(reinterpret_cast<const unsigned char*>(phrase.data()), 32);

    uint8_t* d_remaining_seed_buf = nullptr;
    if (bytes_in_last_chunk > 0) {
        cudaMallocManaged(&d_remaining_seed_buf, sizeof(uint8_t) * bytes_in_last_chunk);
        cudaMemcpy(d_remaining_seed_buf, &hasher.buf, bytes_in_last_chunk, cudaMemcpyDefault);
    }
    auto d_remaining_seed = cuda::std::span<const uint8_t>(d_remaining_seed_buf, bytes_in_last_chunk); 

    struct sha256state* d_partial_state = nullptr;
    cudaMallocManaged(&d_partial_state, sizeof(struct sha256state));
    cudaMemcpy(d_partial_state, &hasher.s, sizeof(struct sha256state), cudaMemcpyDefault);

    int* d_found_flag = nullptr;
    cudaMallocManaged(&d_found_flag, sizeof(int));
    *d_found_flag = 0;

    struct mCaptchaResult* d_found_result = nullptr;
    cudaMallocManaged(&d_found_result, sizeof(struct mCaptchaResult));

    auto[gridSize, blockSize] = getBestBigKernelLaunchParams(k_work);

    k_work<<<gridSize, blockSize>>>(
        d_remaining_seed,
        nonce_max,
        d_partial_state,
        no_full_chunks * 64 * 8,
        target,
        d_found_flag,
        d_found_result
    );

    cudaDeviceSynchronize();

    std::optional<struct mCaptchaResult> result = std::nullopt;
    if (*d_found_flag) {
        result = *d_found_result;
    }

    cudaFree(d_remaining_seed_buf);
    cudaFree(d_partial_state);
    cudaFree(d_found_flag);
    cudaFree(d_found_result);

    return result;
}