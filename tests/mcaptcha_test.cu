#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include <catch2/generators/catch_generators_adapters.hpp>
#include <span>
#include <set>
#include <utility>
#include <string>
#include <exception>
#include <limits>

#include <vendor/bitcoin/crypto/sha256.h>
#include <work_mcaptcha.h>
#include <generators.h>

// Adapted from: https://stackoverflow.com/questions/51538694/how-to-create-a-128-bit-integer-literal
consteval __uint128_t operator""_uint128_t(const char* x)
{
    __uint128_t y = 0;
    for (int i = 0; x[i] != '\0'; ++i)
    {
        y *= 10ull;
        if ('0' <= x[i] && x[i] <= '9') {
            y += x[i] - '0';
        } else {
            throw std::domain_error("128-bit number not in decimal");
        }
    }
    return y;
}

TEST_CASE("M1-CPU: Difficulty 1", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 1, 10);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(1 , 126659543682743707024698831808895164318_uint128_t)
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M1-GPU: Difficulty 1", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 1, 10);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(1 , 126659543682743707024698831808895164318_uint128_t)
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M2-CPU: Range upper bound", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    
    SECTION("Should not work") {
        auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 68594);
        REQUIRE_FALSE(res.has_value());
    }

    SECTION("Should work") {
        auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 68595);
        REQUIRE(res.has_value());
        std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
            std::make_pair(68595, 340280326216769398578171538601404189568_uint128_t)
        };
        REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
    }
}
TEST_CASE("M2-GPU: Range upper bound", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    
    SECTION("Should not work") {
        auto res = do_mCaptcha_gpu(salt, phrase, 100000, 68594);
        REQUIRE_FALSE(res.has_value());
    }

    SECTION("Should work") {
        auto res = do_mCaptcha_gpu(salt, phrase, 100000, 68595);
        REQUIRE(res.has_value());
        std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
            std::make_pair(68595, 340280326216769398578171538601404189568_uint128_t)
        };
        REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
    }
}
TEST_CASE("M3-CPU: `nonce_max` = 0", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 1, 0);
    REQUIRE_FALSE(res.has_value());
}
TEST_CASE("M3-GPU: `nonce_max` = 0", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 1, 0);
    REQUIRE_FALSE(res.has_value());
}
TEST_CASE("M4-CPU: Comparison direction", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 2, 10);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(2,  325718469178364122124380321832549433892_uint128_t),
        std::make_pair(3,  273337430437436863077855571783256872073_uint128_t),
        std::make_pair(6,  291034270725685709372292998087259037858_uint128_t),
        std::make_pair(8,  174589752735751933252552269641245960050_uint128_t),
        std::make_pair(9,  294070099338284967168253457027345426914_uint128_t),
        std::make_pair(10, 254743393343757076210816841954114936845_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M4-GPU: Comparison direction", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 2, 10);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(2,  325718469178364122124380321832549433892_uint128_t),
        std::make_pair(3,  273337430437436863077855571783256872073_uint128_t),
        std::make_pair(6,  291034270725685709372292998087259037858_uint128_t),
        std::make_pair(8,  174589752735751933252552269641245960050_uint128_t),
        std::make_pair(9,  294070099338284967168253457027345426914_uint128_t),
        std::make_pair(10, 254743393343757076210816841954114936845_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M5-CPU: No salt", "[mCaptcha][CPU]") {
    std::u8string salt = u8""; // Pass the salt will you!?
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 140000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(137417,  340280158354824799601019269489227396883_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M5-GPU: No salt", "[mCaptcha][GPU]") {
    std::u8string salt = u8"";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 140000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(137417,  340280158354824799601019269489227396883_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M6-CPU: Padding boundary crossed during search", "[mCaptcha][CPU]") {
    std::u8string salt = u8"ssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 110000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(107855,  340279719024896571489703591392694787880_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M6-GPU: Padding boundary crossed during search", "[mCaptcha][GPU]") {
    std::u8string salt = u8"ssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 110000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(107855,  340279719024896571489703591392694787880_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M7-CPU: Always need two final blocks", "[mCaptcha][CPU]") {
    std::u8string salt = u8"sssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 80000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(77478,  340282157057810954530350741206705711575_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M7-GPU: Always need two final blocks", "[mCaptcha][GPU]") {
    std::u8string salt = u8"sssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 80000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(77478,  340282157057810954530350741206705711575_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M8-CPU: 64 byte prefix", "[mCaptcha][CPU]") {
    std::u8string salt = u8"ssssssssssssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 75000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(73753,  340279651808145608629192764146043458245_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M8-GPU: 64 byte prefix", "[mCaptcha][GPU]") {
    std::u8string salt = u8"ssssssssssssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 75000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(73753,  340279651808145608629192764146043458245_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M9-CPU: Multi-block salt", "[mCaptcha][CPU]") {
    std::u8string salt = u8"ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 16000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(15626,  340281674809694300494073292460849175911_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M9-GPU: Multi-block salt", "[mCaptcha][GPU]") {
    std::u8string salt = u8"ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 16000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(15626,  340281674809694300494073292460849175911_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M10-CPU: Multi-byte UTF-8 salt", "[mCaptcha][CPU]") {
    std::u8string salt = u8"sälz€";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 75000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(74164,  340279014806201573062139070728206948844_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M10-GPU: Multi-byte UTF-8 salt", "[mCaptcha][GPU]") {
    std::u8string salt = u8"sälz€";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 75000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(74164,  340279014806201573062139070728206948844_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M11-CPU: Realistic alphanumeric phrase", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 37000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(36397,  340279333792226842955837542406318682819_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M11-GPU: Realistic alphanumeric phrase", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6";
    auto res = do_mCaptcha_gpu(salt, phrase, 100000, 37000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(36397,  340279333792226842955837542406318682819_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
TEST_CASE("M12-CPU: Difficulty zero", "[mCaptcha][CPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 0, 10);
    REQUIRE_FALSE(res.has_value());
}
TEST_CASE("M12-GPU: Difficulty zero", "[mCaptcha][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_gpu(salt, phrase, 0, 10);
    REQUIRE_FALSE(res.has_value());
}

constexpr __uint128_t uint128_max = std::numeric_limits<__uint128_t>::max();

__uint128_t threshold(uint32_t difficultyFactor) {
	// "get_difficulty" in mcaptcha_pow_sha256; integer (floor) division
	return uint128_max - (uint128_max / difficultyFactor);
}

TEST_CASE("P1g", "[mCaptcha][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6";
    auto res = do_mCaptcha_gpu(salt, phrase, 10000, 10000000);
    if (res.has_value()) {
        REQUIRE(threshold(10000) <= res.value().score);
    }
}
TEST_CASE("P1h", "[AnubisJS][GPU]") {
    auto seed = GENERATE(take(10, randomBytes(1, 256)));
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6";
    auto res = do_mCaptcha_gpu(salt, phrase, 10000, 10000000);
    
    const size_t total_length = salt.size() + sizeof(uint64_t) + phrase.size();
    constexpr uint64_t phrase_length = 32;
    const __uint128_t target = threshold(10000);

    unsigned char hash[32] = {0};
    CSHA256 hasher = CSHA256();
    hasher.Write(reinterpret_cast<const unsigned char*>(salt.data()), salt.size());
    hasher.Write(reinterpret_cast<const unsigned char*>(&phrase_length), sizeof(uint64_t));
    hasher.Write(reinterpret_cast<const unsigned char*>(phrase.data()), 32);
    CSHA256 saved_state = hasher;

    uint64_t nonce = res.value().nonce;
    std::string digits = std::to_string(nonce);
    hasher.Write(reinterpret_cast<const unsigned char*>(digits.data()), digits.size());
    hasher.Finalize(hash);
    
    // the score is the first 16 bytes of the digest read as a big-endian integer
    __uint128_t s = 0;
    for (size_t i = 0; i < 16; i++) s = (s << 8) | hash[i];
    
    REQUIRE(s == res.value().score);
}
TEST_CASE("P2c: No state carried between calls", "[AnubisWASM][GPU]") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6";
    auto res1 = do_mCaptcha_gpu(salt, phrase, 100000, 37000);
    REQUIRE(res1.has_value());
    
    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(36397,  340279333792226842955837542406318682819_uint128_t),
    };

    REQUIRE(correct_results.contains(std::make_pair(res1.value().nonce, res1.value().score)));

    auto res2 = do_mCaptcha_gpu(salt, phrase, 100000, 35000);
    REQUIRE_FALSE(res2.has_value());
}