#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include <catch2/generators/catch_generators_adapters.hpp>
#include <span>
#include <vector>
#include <string>
#include <random>

#include <bit>

#include <vendor/bitcoin/crypto/sha256.h>
#include <generators.h>
#include <count_zeroes.h>
#include <work_anubis.h>


TEST_CASE("A1-CPU: Zero difficulty", "[AnubisJS][CPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 10, 0);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 0);
}
TEST_CASE("A1-GPU: Zero difficulty", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 10, 0);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 0);
}
TEST_CASE("A2-CPU: `nonce_max` inclusive boundary", "[AnubisJS][CPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    SECTION("Not in inclusive range") {
        auto res = do_anubis_js_singlethreaded_cpu(seed_span, 14470, 16);
        REQUIRE_FALSE(res.has_value());
    }

    SECTION("In inclusive range") {
        auto res = do_anubis_js_singlethreaded_cpu(seed_span, 14471, 16);
        REQUIRE(res.has_value());
        REQUIRE(res.value() == 14471);
    }
}
TEST_CASE("A2-GPU: `nonce_max` inclusive boundary", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    SECTION("Not in inclusive range") {
        auto res = do_anubis_js_gpu(seed_span, 14470, 16);
        REQUIRE_FALSE(res.has_value());
    }

    SECTION("In inclusive range") {
        auto res = do_anubis_js_gpu(seed_span, 14471, 16);
        REQUIRE(res.has_value());
        REQUIRE(res.value() == 14471);
    }
}
TEST_CASE("A3-CPU: Range too small", "[AnubisJS][CPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 1, 0);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 0);
    
}
TEST_CASE("A3-GPU: Range too small", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    auto res = do_anubis_js_gpu(seed_span, 1, 0);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 0);

}
TEST_CASE("A4-CPU: Difficulty not multiple of four", "[AnubisJS][CPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 3000, 13);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 2846);
}
TEST_CASE("A4-GPU: Difficulty not multiple of four", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 3000, 13);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 2846);
}
TEST_CASE("A5-CPU: Empty seed", "[AnubisJS][CPU]") {
    std::string seed = "";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 90000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 88484);
}
TEST_CASE("A5-GPU: Empty seed", "[AnubisJS][GPU]") {
    std::string seed = "";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 90000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 88484);
}
TEST_CASE("A6-CPU: One block seed", "[AnubisJS][CPU]") {
    std::string seed = "092136e376e17ab5843512b0633bcbf7ded1e5053db3335ac42a13b256075c65";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 120000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 115148);
}
TEST_CASE("A6-GPU: One block seed", "[AnubisJS][GPU]") {
    std::string seed = "092136e376e17ab5843512b0633bcbf7ded1e5053db3335ac42a13b256075c65";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 120000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 115148);
}
TEST_CASE("A7-CPU: Padding boundary crossed during search", "[AnubisJS][CPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 5000, 12);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 4043);
}
TEST_CASE("A7-GPU: Padding boundary crossed during search", "[AnubisJS][GPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 5000, 12);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 4043);
}
TEST_CASE("A8-CPU: Always needs two final blocks", "[AnubisJS][CPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 10000, 12);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 9465);
}
TEST_CASE("A8-GPU: Always needs two final blocks", "[AnubisJS][GPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 10000, 12);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 9465);
}
TEST_CASE("A9-CPU: Multi-block seed with leftover bytes", "[AnubisJS][CPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 60000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 59281);
}
TEST_CASE("A9-GPU: Always Needs Two Final Blocks", "[AnubisJS][GPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 60000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 59281);
}
TEST_CASE("A10-CPU: Two block seed", "[AnubisJS][CPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 7000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 6881);
}
TEST_CASE("A10-GPU: Two block seed", "[AnubisJS][GPU]") {
    std::string seed = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 7000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 6881);
}
TEST_CASE("A11-CPU: Non-UTF-8 bytes", "[AnubisJS][CPU]") {
    std::vector<uint8_t> seed = {0x00, 0xff, 0x80, 0x0a};
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 21000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 20335);
}
TEST_CASE("A11-GPU: Non-UTF-8 bytes", "[AnubisJS][GPU]") {
    std::vector<uint8_t> seed = {0x00, 0xff, 0x80, 0x0a};
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 21000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 20335);
}
TEST_CASE("A12-CPU: Multi-byte UTF-8", "[AnubisJS][CPU]") {
    std::string seed = "héllo wörld";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_singlethreaded_cpu(seed_span, 50000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 48765);
}
TEST_CASE("A12-GPU: Multi-byte UTF-8", "[AnubisJS][GPU]") {
    std::string seed = "héllo wörld";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 50000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 48765);
}

TEST_CASE("P1a", "[AnubisJS][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    auto seed_span = std::span<uint8_t>(seed);
    auto res = do_anubis_js_gpu(seed_span, 0x1 << 20, 12);
    if (res.has_value()) {
        unsigned char hash[32] = {0};

        std::string nonce_to_string = std::to_string(res.value());

        CSHA256 hasher = CSHA256();
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), seed.size());
        hasher.Write(reinterpret_cast<const unsigned char*>(nonce_to_string.data()), nonce_to_string.size());
        hasher.Finalize(hash);
        
        REQUIRE(hash_countl_zero(hash) >= 12);
    }
}
TEST_CASE("P1b", "[AnubisJS][GPU]") {
    auto seed = GENERATE(take(10, randomUTF8String(1, 256)));
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 0x1 << 20, 12);
    if (res.has_value()) {
        unsigned char hash[32] = {0};

        std::string nonce_to_string = std::to_string(res.value());

        CSHA256 hasher = CSHA256();
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), seed.size());
        hasher.Write(reinterpret_cast<const unsigned char*>(nonce_to_string.data()), nonce_to_string.size());
        hasher.Finalize(hash);
        
        REQUIRE(hash_countl_zero(hash) >= 12);
    }
}
TEST_CASE("P1c", "[AnubisJS][GPU]") {
    auto seed = GENERATE(take(10, randomString(1, 256, U"0123456789abcdefghijklmnopqrstuvwyxzABCDEFGHIJKLMNOPQRSTUVWYXZ!\"£$%^&*()-_=+[{}];:'@#~,<.>/?¬`|\\")));
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    auto res = do_anubis_js_gpu(seed_span, 0x1 << 20, 12);
    if (res.has_value()) {
        unsigned char hash[32] = {0};

        std::string nonce_to_string = std::to_string(res.value());

        CSHA256 hasher = CSHA256();
        hasher.Write(reinterpret_cast<const unsigned char*>(seed.data()), seed.size());
        hasher.Write(reinterpret_cast<const unsigned char*>(nonce_to_string.data()), nonce_to_string.size());
        hasher.Finalize(hash);
        
        REQUIRE(hash_countl_zero(hash) >= 12);
    }
}
TEST_CASE("P1d", "[AnubisJS][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    auto seed_span = std::span<uint8_t>(seed);
    auto res_gpu = do_anubis_js_gpu(seed_span, 0x1 << 20, 12);
    auto res_cpu = do_anubis_js_singlethreaded_cpu(seed_span, 0x1 << 20, 12);
    REQUIRE(res_gpu.has_value() == res_cpu.has_value());
    if (res_cpu.has_value()) {
        REQUIRE(res_cpu.value() <= res_gpu.value());
    }
}
TEST_CASE("P2a: No state carried between calls", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    auto res1 = do_anubis_js_gpu(seed_span, 15000, 16);
    REQUIRE(res1.has_value());
    REQUIRE(res1.value() == 14471);

    auto res2 = do_anubis_js_gpu(seed_span, 14470, 16);
    REQUIRE_FALSE(res2.has_value());
    
}
TEST_CASE("P3a: Impossible difficulty", "[AnubisJS][GPU]") {
    std::string seed = "seed";
    auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size());
    
    auto res = do_anubis_js_gpu(seed_span, 1000, 257);
    REQUIRE_FALSE(res.has_value());
}