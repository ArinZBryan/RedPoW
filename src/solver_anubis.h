#pragma once
#include <string>
#include <vector>
#include <cstdint>
#include <cpr/cpr.h>
#include <vendor/simdjson/simdjson.h>
#include <lexbor/dom/dom.h>

namespace anubis {

enum class Algorithm { unset = 0, fast, slow, sha256, argon2id, hashx, metarefresh, preact };
struct Rules { Algorithm algorithm{}; uint32_t difficulty{}; };
struct Metadata { std::string Referer; std::string User_Agent; std::string X_Real_IP;};
struct Challenge { 
    std::string issuedAt;
    Metadata metadata;
    std::string id;
    std::string method;
    std::string randomData;
    std::string policyRuleHash;
    uint32_t difficulty;
    bool spent;
    std::vector<std::string> extensions;
};
struct ChallengeSpec { Rules rules; Challenge challenge; };

class AnubisSolver {
    cpr::Url protected_url;
    cpr::Cookies cookie_jar;
    cpr::Header fake_browser_header;
    simdjson::ondemand::parser parser;
    std::vector<char> parsebuf;
    ChallengeSpec challenge_specification;

    simdjson::ondemand::document scriptElementToJsonDocument(lxb_dom_node_t* e);

    std::string_view getStringFromTextNode(lxb_dom_node_t* text_node);

    void parseChallengeSpecFromTextNode(lxb_dom_node_t* text_node);

    std::vector<std::string> extractStyleImportURLs(lxb_dom_node_t *style_node);
    std::string chooseRedirect(std::string_view current_url, std::string_view public_url);

    std::string makePassURL(std::string_view base_prefix, std::string_view id, std::string_view hash_hex_string, std::string_view nonce_decimal_string, std::string_view redirect_URL, std::string_view elapsed_ms_decimal_string);

    std::string hashToHexString(const std::array<uint8_t, 32>& hash);

public:
    class JSONException  : public std::runtime_error { using std::runtime_error::runtime_error; };
    class HTTPException  : public std::runtime_error { using std::runtime_error::runtime_error; };
    class ParseException : public std::runtime_error { using std::runtime_error::runtime_error; };

    AnubisSolver(std::string protected_url);
        
    cpr::Cookies accessProtectedResource(bool gpu);
};

}