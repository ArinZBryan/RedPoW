#include <catch2/catch_test_macros.hpp>
#include <span>
#include <set>
#include <utility>
#include <string>
#include <exception>
#include <work_mcaptcha.h>

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

TEST_CASE("CPU mCaptcha algorithm implementation is correct") {
    std::u8string salt = u8"salt";
    std::u8string phrase = u8"phrase00000000000000000000000000";
    auto res = do_mCaptcha_singlethreaded_cpu(salt, phrase, 100000, 1000000);
    REQUIRE(res.has_value());

    std::set<std::pair<uint64_t, __uint128_t>> correct_results = {
        std::make_pair(68595 , 340280326216769398578171538601404189568_uint128_t),
        std::make_pair(100168, 340281400596505208478919850413973404024_uint128_t),
        std::make_pair(334495, 340281292256920490611213286277052435598_uint128_t),
        std::make_pair(339599, 340279885395835558303853046454517700375_uint128_t),
        std::make_pair(510154, 340280922106404398168236089850400577420_uint128_t),
        std::make_pair(533797, 340280258330566364598096012726791182550_uint128_t),
        std::make_pair(750791, 340281291616541658301735331586721933482_uint128_t),
        std::make_pair(888081, 340282347939652798078305675774435538654_uint128_t)
    };

    REQUIRE(correct_results.contains(std::make_pair(res.value().nonce, res.value().score)));
}
