#pragma once
#include <catch2/generators/catch_generators.hpp>
#include <catch2/generators/catch_generators_adapters.hpp>
#include <vector>
#include <string>
#include <random>

class RandomBytesGenerator final : public Catch::Generators::IGenerator<std::vector<uint8_t>> {
    std::minstd_rand m_rand;
    std::uniform_int_distribution<> m_byte_dist;
    std::uniform_int_distribution<> m_length_dist;
    std::vector<uint8_t> current_value;
public:
    RandomBytesGenerator(size_t min_length, size_t max_length);
    std::vector<uint8_t> const& get() const override;
    bool next() override;
    bool isFinite() const;
    void skipToNthElementImpl(std::size_t n);
};

Catch::Generators::GeneratorWrapper<std::vector<uint8_t>> randomBytes(size_t min_length, size_t max_length);

class RandomUTF8StringGenerator final : public Catch::Generators::IGenerator<std::u8string> {
    std::minstd_rand m_rand;
    std::uniform_int_distribution<> m_codepoint_dist;
    std::uniform_int_distribution<> m_length_dist;
    std::u8string current_value;

public:
    RandomUTF8StringGenerator(size_t min_length, size_t max_length);
    
    void append_utf8(std::u8string& out, uint32_t codepoint) const;
    std::u8string const& get() const override;
    bool next() override;
    bool isFinite() const;
    void skipToNthElementImpl(std::size_t n);
};

Catch::Generators::GeneratorWrapper<std::u8string> randomUTF8String(size_t min_length, size_t max_length);

class RandomCharsetUTF8StringGenerator final : public Catch::Generators::IGenerator<std::u8string> {
    std::minstd_rand m_rand;
    std::vector<char32_t> charset;
    std::uniform_int_distribution<> m_codepoint_dist;
    std::uniform_int_distribution<> m_length_dist;
    std::u8string current_value;
public:
    
    RandomCharsetUTF8StringGenerator(size_t min_length, size_t max_length, std::u32string charset);
    
    void append_utf8(std::u8string& out, uint32_t codepoint) const;
    std::u8string const& get() const override;
    bool next() override;
    bool isFinite() const;
    void skipToNthElementImpl(std::size_t n);
};

Catch::Generators::GeneratorWrapper<std::u8string> randomString(size_t min_length, size_t max_length, std::u32string charset);
