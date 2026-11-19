#include <generators.h>

RandomBytesGenerator::RandomBytesGenerator(size_t min_length, size_t max_length) : m_rand(std::random_device{}()), m_byte_dist(0, 255), m_length_dist(min_length, max_length) {
    static_cast<void>(next());
}
bool RandomBytesGenerator::next() {
    size_t next_length = m_length_dist(m_rand);
    current_value = std::vector<uint8_t>(next_length);
    for (int i = 0; i < next_length; i++) {
        current_value[i] = m_byte_dist(m_rand);
    }
    return true;
}
bool RandomBytesGenerator::isFinite() const { return false; }   
void RandomBytesGenerator::skipToNthElementImpl(std::size_t n) {
    auto current_index  = currentElementIndex();
    assert(current_index <= n);
    for (; current_index < n; ++current_index) {
        static_cast<void>(next());
    }
}
std::vector<uint8_t> const& RandomBytesGenerator::get() const {
    return current_value;
}
Catch::Generators::GeneratorWrapper<std::vector<uint8_t>> randomBytes(size_t min_length, size_t max_length) {
    return Catch::Generators::GeneratorWrapper<std::vector<uint8_t>>(
        new RandomBytesGenerator(min_length, max_length)
    );
}

RandomUTF8StringGenerator::RandomUTF8StringGenerator(size_t min_length, size_t max_length) : m_rand(std::random_device{}()), m_codepoint_dist(0, 0x10FFFF - 0x800), m_length_dist(min_length, max_length) {
    static_cast<void>(next());
};
void RandomUTF8StringGenerator::append_utf8(std::u8string& out, uint32_t codepoint) const {
    if (codepoint <= 0x7f) {
        out.push_back(static_cast<char8_t>(codepoint));
    } else if (codepoint <= 0x7ff) {
        out.push_back(static_cast<char8_t>(0xc0 | ((codepoint >> 6) & 0x1f)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint & 0x3F)));
    } else if (codepoint <= 0xFFFF) {
        out.push_back(static_cast<char8_t>(0xE0 | ((codepoint >> 12) & 0x0F)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 6) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint & 0x3F)));
    } else if (codepoint <= 0x10FFFF) {
        out.push_back(static_cast<char8_t>(0xF0 | ((codepoint >> 18) & 0x07)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 12) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 6) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint)));
    }
}
bool RandomUTF8StringGenerator::next() {
    size_t next_length = m_length_dist(m_rand);
    current_value = std::u8string();
    current_value.reserve(next_length * 3);
    for (size_t i = 0; i < next_length; i++) {
        uint32_t codepoint = m_codepoint_dist(m_rand);
        if (codepoint >= 0xd800) {
            codepoint += 0x800;
        }
        append_utf8(current_value, codepoint);
    }
    return true;
}
bool RandomUTF8StringGenerator::isFinite() const { return false; }
void RandomUTF8StringGenerator::skipToNthElementImpl(std::size_t n) {
    auto current_index  = currentElementIndex();
    assert(current_index <= n);
    for (; current_index < n; ++current_index) {
        static_cast<void>(next());
    }
}
std::u8string const& RandomUTF8StringGenerator::get() const {
    return current_value;
}
Catch::Generators::GeneratorWrapper<std::u8string> randomUTF8String(size_t min_length, size_t max_length) {
    return Catch::Generators::GeneratorWrapper<std::u8string>(
        new RandomUTF8StringGenerator(min_length, max_length)
    );
}

RandomCharsetUTF8StringGenerator::RandomCharsetUTF8StringGenerator(size_t min_length, size_t max_length, std::u32string charset) : 
    m_rand(std::random_device{}()), 
    charset(charset.begin(), charset.end()), 
    m_codepoint_dist(0, charset.length() - 1), 
    m_length_dist(min_length, max_length)
{
    static_cast<void>(next());
}
void RandomCharsetUTF8StringGenerator::append_utf8(std::u8string& out, uint32_t codepoint) const {
    if (codepoint <= 0x7f) {
        out.push_back(static_cast<char8_t>(codepoint));
    } else if (codepoint <= 0x7ff) {
        out.push_back(static_cast<char8_t>(0xc0 | ((codepoint >> 6) & 0x1f)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint & 0x3F)));
    } else if (codepoint <= 0xFFFF) {
        out.push_back(static_cast<char8_t>(0xE0 | ((codepoint >> 12) & 0x0F)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 6) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint & 0x3F)));
    } else if (codepoint <= 0x10FFFF) {
        out.push_back(static_cast<char8_t>(0xF0 | ((codepoint >> 18) & 0x07)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 12) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | ((codepoint >> 6) & 0x3F)));
        out.push_back(static_cast<char8_t>(0x80 | (codepoint)));
    }
}
bool RandomCharsetUTF8StringGenerator::next() {
    size_t next_length = m_length_dist(m_rand);
    current_value = std::u8string();
    current_value.reserve(next_length * 3);
    for (size_t i = 0; i < next_length; i++) {
        uint32_t codepoint = m_codepoint_dist(m_rand);
        append_utf8(current_value, charset[codepoint]);
    }
    return true;
}
bool RandomCharsetUTF8StringGenerator::isFinite() const { return false; }
void RandomCharsetUTF8StringGenerator::skipToNthElementImpl(std::size_t n) {
    auto current_index  = currentElementIndex();
    assert(current_index <= n);
    for (; current_index < n; ++current_index) {
        static_cast<void>(next());
    }
}
std::u8string const& RandomCharsetUTF8StringGenerator::get() const {
    return current_value;
}
Catch::Generators::GeneratorWrapper<std::u8string> randomString(size_t min_length, size_t max_length, std::u32string charset) {
    return Catch::Generators::GeneratorWrapper<std::u8string>(
        new RandomCharsetUTF8StringGenerator(min_length, max_length, charset)
    );
}
