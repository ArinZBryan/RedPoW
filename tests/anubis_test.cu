#include <catch2/catch_test_macros.hpp>
#include <span>
#include <work_anubis.h>


TEST_CASE("CPU Anubis JS algorithm implementation is correct") {
    std::string seed = "seed";
    auto res = do_anubis_js_singlethreaded_cpu(std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size()), 15000, 16);
    REQUIRE(res.has_value());
    REQUIRE(res.value() == 14471);
}

TEST_CASE("GPU Anubis JS algorithm implementation is correct") {
    std::string seed = "seed";
    auto res = do_anubis_js_gpu(std::span<uint8_t>(reinterpret_cast<uint8_t*>(seed.data()), seed.size()), 15000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 14471);
}

TEST_CASE("CPU Anubis WASM algorithm implementation is correct") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_singlethreaded_cpu(std::span<uint8_t>(seed, 4), 85000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 82496);
}

TEST_CASE("GPU Anubis WASM algorithm implementation is correct") {
    uint8_t seed[] = {0xde, 0xad, 0xbe, 0xef};
    auto res = do_anubis_wasm_gpu(std::span<uint8_t>(seed, 4), 85000, 16);

    REQUIRE(res.has_value());
    REQUIRE(res.value() == 82496);
}