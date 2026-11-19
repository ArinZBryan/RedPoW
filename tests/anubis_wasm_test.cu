#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include <catch2/generators/catch_generators_adapters.hpp>

#include <span>
#include <array>

#include <vendor/bitcoin/crypto/sha256.h>
#include <vendor/bitcoin/compat/endian.h>
#include <work_anubis.h>
#include <count_zeroes.h>
#include <generators.h>

TEST_CASE("W1a-CPU: Big-endian nonce", "[AnubisWASM][CPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0x7f};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 20000, 16);

    REQUIRE(res.has_value());
    CHECK_FALSE(res.value() == 23148);
    REQUIRE(res.value() == 13489);
}
TEST_CASE("W1a-GPU: Big-endian nonce", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0x7f};
    auto res = do_anubis_wasm_gpu(seed, 20000, 16);

    REQUIRE(res.has_value());
    CHECK_FALSE(res.value() == 23148);
    REQUIRE(res.value() == 13489);
}
TEST_CASE("W1b-CPU: Little-endian nonce", "[AnubisWASM][CPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 85000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 82496);
}
TEST_CASE("W1b-GPU: Little-endian nonce", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_gpu(seed, 85000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 82496);
}
TEST_CASE("W2-CPU: Endianness threshold", "[AnubisWASM][CPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0x80};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 300000, 16);

    REQUIRE(res.has_value());
    CHECK_FALSE(res.value() == 17022);
    REQUIRE(res.value() == 296575);
}
TEST_CASE("W2-GPU: Endianness threshold", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0x80};
    auto res = do_anubis_wasm_gpu(seed, 300000, 16);

    REQUIRE(res.has_value());
    CHECK_FALSE(res.value() == 17022);
    REQUIRE(res.value() == 296575);
}
TEST_CASE("A13-CPU: Empty seed", "[AnubisWASM][CPU]") {
    std::span<uint8_t> seed{};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 140000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 129544);
}
TEST_CASE("A13-GPU: Empty seed", "[AnubisWASM][GPU]") {
    std::span<uint8_t> seed{};
    auto res = do_anubis_wasm_gpu(seed, 140000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 129544);
}
TEST_CASE("W3-CPU: 32-byte raw challenge", "[AnubisWASM][CPU]") {
    uint8_t seed[] = {0x09, 0x21, 0x36, 0xe3, 0x76, 0xe1, 0x7a, 0xb5, 0x84, 0x35, 0x12, 0xb0, 0x63, 0x3b, 0xcb, 0xf7, 0xde, 0xd1, 0xe5, 0x05, 0x3d, 0xb3, 0x33, 0x5a, 0xc4, 0x2a, 0x13, 0xb2, 0x56, 0x07, 0x5c, 0x65};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 51000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 50122);
}
TEST_CASE("W3-GPU: 32-byte raw challenge", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0x09, 0x21, 0x36, 0xe3, 0x76, 0xe1, 0x7a, 0xb5, 0x84, 0x35, 0x12, 0xb0, 0x63, 0x3b, 0xcb, 0xf7, 0xde, 0xd1, 0xe5, 0x05, 0x3d, 0xb3, 0x33, 0x5a, 0xc4, 0x2a, 0x13, 0xb2, 0x56, 0x07, 0x5c, 0x65};
    auto res = do_anubis_wasm_gpu(seed, 51000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 50122);
}
TEST_CASE("W4-CPU: Padding boundary", "[AnubisWASM][CPU]") {
    std::array<uint8_t, 52> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 17000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 16274);
}
TEST_CASE("W4-GPU: Padding boundary", "[AnubisWASM][GPU]") {
    std::array<uint8_t, 52> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_gpu(seed, 17000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 16274);
}
TEST_CASE("W5-CPU: Leftover bytes", "[AnubisWASM][CPU]") {
    std::array<uint8_t, 61> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 22000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 21269);
}
TEST_CASE("W5-GPU: Leftover bytes", "[AnubisWASM][GPU]") {
    std::array<uint8_t, 61> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_gpu(seed, 22000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 21269);
}
TEST_CASE("W6-CPU: One block seed", "[AnubisWASM][CPU]") {
    std::array<uint8_t, 64> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, 31000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 30613);
}
TEST_CASE("W6-GPU: One block seed", "[AnubisWASM][GPU]") {
    std::array<uint8_t, 64> seed;
    seed.fill(0x01);
    auto res = do_anubis_wasm_gpu(seed, 31000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 30613);
}
/*TEST_CASE("A15-CPU: Full range with no solution", "[AnubisWASM][CPU][.slow]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_singlethreaded_cpu(seed, UINT32_MAX, 64);
    REQUIRE_FALSE(res.has_value());
}*/
TEST_CASE("A15-GPU: Full range with no solution", "[AnubisWASM][GPU][.slow]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_gpu(seed, UINT32_MAX, 64);
    REQUIRE_FALSE(res.has_value());
}

TEST_CASE("P1e", "[AnubisWASM][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    auto seed_span = std::span<uint8_t>(seed);
    auto res = do_anubis_wasm_gpu(seed_span, 0x1 << 20, 12);
    if (res.has_value()) {
        unsigned char hash[32] = {0};

        bool nonce_is_little_endian = seed_span[seed_span.size() - 1] >= 128;
        uint32_t nonce_bits = nonce_is_little_endian ? res.value() : htobe32(res.value());

        CSHA256 hasher = CSHA256();
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), seed.size());
        hasher.Write(reinterpret_cast<const unsigned char*>(&nonce_bits), sizeof(uint32_t));
        hasher.Finalize(hash);
        

        REQUIRE(hash_countl_zero(hash) >= 12);
    }
}
TEST_CASE("P1f", "[AnubisWASM][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    auto seed_span = std::span<uint8_t>(seed);
    auto res_gpu = do_anubis_wasm_gpu(seed_span, 0x1 << 20, 12);
    auto res_cpu = do_anubis_wasm_singlethreaded_cpu(seed_span, 0x1 << 20, 12);
    REQUIRE(res_gpu.has_value() == res_cpu.has_value());
    if (res_cpu.has_value()) {
        REQUIRE(res_cpu.value() <= res_gpu.value());
    }
}
TEST_CASE("P2b: No state carried between calls", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    
    auto res1 = do_anubis_wasm_gpu(seed, 85000, 16);
    REQUIRE(res1.has_value());
    REQUIRE(res1.value() == 82496);

    auto res2 = do_anubis_wasm_gpu(seed, 82495, 16);
    REQUIRE_FALSE(res2.has_value());
    
}
TEST_CASE("P3b: Impossible difficulty", "[AnubisWASM][GPU]") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};   
    auto res = do_anubis_wasm_gpu(seed, 1000, 257);
    REQUIRE_FALSE(res.has_value());
}