#pragma once

#include <optional>
#include <cstdint>
#include <span>

/**
 * @brief Perform the Anubis fast and slow PoW schemes on the CPU using a single thread
 * @param seed The fixed bytes that are part of every hash. This could be either a utf-8 encoded string, or raw bytes
 * @param nonce_max The largest nonce to try in the search. To prevent giving up, set this to the unsigned 64-bit maximum
 * @param difficulty The number of zero _bits_ to search for at the start of the hash
 * @returns The nonce that succeeded the difficulty check if one was found within the nonce range.
 */
std::optional<uint64_t> do_anubis_js_singlethreaded_cpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty);

/**
 * @brief Perform the Anubis fast and slow PoW schemes on the GPU using as many threads as possible
 * @param seed The fixed bytes that are part of every hash. This could be either a utf-8 encoded string, or raw bytes
 * @param nonce_max The largest nonce to try in the search. To prevent giving up, set this to the unsigned 64-bit maximum
 * @param difficulty The number of zero _bits_ to search for at the start of the hash
 * @returns The nonce that succeeded the difficulty check if one was found within the nonce range.
 */
std::optional<uint64_t> do_anubis_js_gpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty);

/**
 * @brief Perform the Anubis WASM SHA256 PoW scheme on the CPU using a single thread
 * @param seed The fixed bytes that are part of every hash. This could be either a utf-8 encoded string, or raw bytes
 * @param nonce_max The largest nonce to try in the search. To prevent giving up, set this to the unsigned 64-bit maximum
 * @param difficulty The number of zero _bits_ to search for at the start of the hash
 * @returns The nonce that succeeded the difficulty check if one was found within the nonce range.
 */
std::optional<uint64_t> do_anubis_wasm_singlethreaded_cpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty);

/**
 * @brief Perform the Anubis WASM SHA256 PoW scheme on the GPU using as many threads as possible
 * @param seed The fixed bytes that are part of every hash. This could be either a utf-8 encoded string, or raw bytes
 * @param nonce_max The largest nonce to try in the search. To prevent giving up, set this to the unsigned 64-bit maximum
 * @param difficulty The number of zero _bits_ to search for at the start of the hash
 * @returns The nonce that succeeded the difficulty check if one was found within the nonce range.
 */
std::optional<uint64_t> do_anubis_wasm_gpu(const std::span<uint8_t>& seed, uint64_t nonce_max, uint32_t difficulty);