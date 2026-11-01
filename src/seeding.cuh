#include <utility.cuh>
#include <cuda/std/span>

/*
    Convert a `DigitsToConvert` digit number, stored in a `uint64_t` to a utf-8
    string, packing it into big-endian `uint32_t`.

    Arguments:
    `DigitsToConvert` must be between 1-10 inclusive
    `n` the number to convert
    `out` the span of uint32_t words in which to write the result
*/
template <uint DigitsToConvert>
__device__ void digits_to_be_utf8_words(uint64_t n, cuda::std::span<uint32_t, 3> out) {
    assert(DigitsToConvert > 0 && DigitsToConvert <= 10);
    constexpr size_t digits_per_word = sizeof(uint32_t) / sizeof(uint8_t);
    
    #pragma unroll
    for (int i = 0; i < DigitsToConvert; i++) {
        const size_t word = i / digits_per_word;
        const size_t byte_position_in_word = i % digits_per_word;
        const size_t bit_position_in_word = byte_position_in_word * 8;
        const uint8_t digit = ('0' + n % 10);
        out[word] |= static_cast<uint32_t>(digit) << 24 - bit_position_in_word; 
        n /= 10;
    }
}

/*
    Shift a uint128_t stored as a span of four uint32_t words right by n bits
*/
__device__ void shr_uint128_t(cuda::std::span<uint32_t, 4> out, size_t n);