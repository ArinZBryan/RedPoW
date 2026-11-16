#pragma once

#include <concepts>
#include <bit>
#include <cstdint>
#include <climits>
#include <cstddef>
#include <type_traits>
#include <utility>

template<std::unsigned_integral TData, std::integral TBy>
__device__ static inline TData rotr(const TData& x, const TBy& s) { return std::rotr(x, s); }
template<std::unsigned_integral TData, std::integral TBy>
__device__ static inline TData rotl(const TData& x, const TBy& s) { return std::rotl(x, s); }
template<std::unsigned_integral TData, std::integral TBy>
__device__ static inline TData shr(const TData& x, const TBy& s) { return x >> s; }
template<std::unsigned_integral TData, std::integral TBy>
__device__ static inline TData shl(const TData& x, const TBy& s) { return x << s; }

__device__ __forceinline__ uint32_t swap_endianness(uint32_t x) { return __byte_perm(x, 0, 0x0123); }
__device__ __forceinline__ uint64_t swap_endianness(uint64_t x) { return ((uint64_t)__byte_perm((uint32_t)x, 0, 0x0123) << 32) |  (uint64_t)__byte_perm((uint32_t)(x >> 32), 0, 0x0123); }
