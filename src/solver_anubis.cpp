#include <string>
#include <exception>
#include <format>
#include <string_view>
#include <chrono>
#include <span>

#include <lexbor/css/css.h>
#include <lexbor/html/html.h>
#include <lexbor/dom/dom.h>
#include <lexbor/core/str.h>

#include <htmldocument.h>
#include <work_anubis.h>
#include <solver_anubis.h>

#define THROW_JSON_PARSE_ERR(result)                                     \
    if (!(result).has_value())                                           \
    {                                                                    \
        std::string msg(simdjson::error_message((result).error()));      \
        throw JSONException(std::format("Json Parsing Error: {}", msg)); \
    }

namespace anubis
{

    simdjson::error_code tag_invoke(simdjson::deserialize_tag, auto &val, Algorithm &out) noexcept
    {
        static constexpr std::pair<std::string_view, Algorithm> names[] = {
            {"fast", Algorithm::fast},
            {"slow", Algorithm::slow},
            {"sha256", Algorithm::sha256},
            {"argon2id", Algorithm::argon2id},
            {"hashx", Algorithm::hashx},
            {"metarefresh", Algorithm::metarefresh},
            {"preact", Algorithm::preact}};
        std::string_view s;
        SIMDJSON_TRY(val.get_string().get(s));
        for (auto [name, alg] : names)
            if (s == name)
            {
                out = alg;
                return simdjson::SUCCESS;
            }
        return simdjson::INCORRECT_TYPE;
    }
    simdjson::error_code tag_invoke(simdjson::deserialize_tag, auto &val, Rules &out) noexcept
    {
        simdjson::ondemand::object o;
        SIMDJSON_TRY(val.get_object().get(o));
        SIMDJSON_TRY(o["algorithm"].get(out.algorithm));
        SIMDJSON_TRY(o["difficulty"].get(out.difficulty));
        return simdjson::SUCCESS;
    }
    simdjson::error_code tag_invoke(simdjson::deserialize_tag, auto &val, Metadata &out) noexcept
    {
        simdjson::ondemand::object o;
        SIMDJSON_TRY(val.get_object().get(o));
        SIMDJSON_TRY(o["Referer"].get(out.Referer)); // use the exact keys from a real payload
        SIMDJSON_TRY(o["User-Agent"].get(out.User_Agent));
        SIMDJSON_TRY(o["X-Real-IP"].get(out.X_Real_IP));
        return simdjson::SUCCESS;
    }
    simdjson::error_code tag_invoke(simdjson::deserialize_tag, auto &val, Challenge &out) noexcept
    {
        simdjson::ondemand::object o;
        SIMDJSON_TRY(val.get_object().get(o));
        SIMDJSON_TRY(o["issuedAt"].get(out.issuedAt));
        SIMDJSON_TRY(o["metadata"].get(out.metadata));
        SIMDJSON_TRY(o["id"].get(out.id));
        SIMDJSON_TRY(o["method"].get(out.method));
        SIMDJSON_TRY(o["randomData"].get(out.randomData));
        SIMDJSON_TRY(o["policyRuleHash"].get(out.policyRuleHash));
        SIMDJSON_TRY(o["difficulty"].get(out.difficulty));
        SIMDJSON_TRY(o["spent"].get(out.spent));
        simdjson::ondemand::value ext;
        SIMDJSON_TRY(o["extensions"].get(ext));
        bool ext_is_null;
        SIMDJSON_TRY(ext.is_null().get(ext_is_null));
        if (ext_is_null)
        {
            out.extensions.clear();
        }
        else
        {
            SIMDJSON_TRY(ext.get(out.extensions));
        }
        return simdjson::SUCCESS;
    }
    simdjson::error_code tag_invoke(simdjson::deserialize_tag, auto &val, ChallengeSpec &out) noexcept
    {
        simdjson::ondemand::object o;
        SIMDJSON_TRY(val.get_object().get(o));
        SIMDJSON_TRY(o["rules"].get(out.rules));
        SIMDJSON_TRY(o["challenge"].get(out.challenge));
        return simdjson::SUCCESS;
    }

    simdjson::ondemand::document AnubisSolver::scriptElementToJsonDocument(lxb_dom_node_t *e)
    {
        if (e == nullptr)
        {
            throw ParseException("Element does not exist");
        }
        if (e->type != LXB_DOM_NODE_TYPE_TEXT)
        {
            throw ParseException("Element is not a <script> element");
        }
        const lexbor_str_t &e_text = reinterpret_cast<lxb_dom_text_t *>(e)->char_data.data;
        parsebuf.resize(e_text.length + simdjson::SIMDJSON_PADDING);
        std::memcpy(parsebuf.data(), e_text.data, e_text.length);
        return parser.iterate(parsebuf.data(), e_text.length, parsebuf.size());
    }

    std::string_view AnubisSolver::getStringFromTextNode(lxb_dom_node_t *text_node)
    {
        simdjson::ondemand::document text_jsonval = scriptElementToJsonDocument(text_node);
        auto text_maybe = text_jsonval.get_string();
        THROW_JSON_PARSE_ERR(text_maybe);
        return text_maybe.value();
    }

    void AnubisSolver::parseChallengeSpecFromTextNode(lxb_dom_node_t *text_node)
    {
        simdjson::ondemand::document text_jsonval = scriptElementToJsonDocument(text_node);
        if (auto err = text_jsonval.get(challenge_specification))
            throw JSONException(std::format("JSON parsing error: {}", simdjson::error_message(err)));
    }

    std::vector<std::string> AnubisSolver::extractStyleImportURLs(lxb_dom_node_t *style_node)
    {
        std::vector<std::string> res;

        size_t css_len = 0;
        lxb_char_t *css = lxb_dom_node_text_content(style_node, &css_len);
        if (css == NULL || css_len == 0)
        {
            return res;
        }

        lxb_css_syntax_tokenizer_t *tkz = lxb_css_syntax_tokenizer_create();
        if (lxb_css_syntax_tokenizer_init(tkz) != LXB_STATUS_OK)
        {
            lxb_dom_document_destroy_text(style_node->owner_document, css);
            lxb_css_syntax_tokenizer_destroy(tkz);
            return res;
        }

        lxb_css_syntax_tokenizer_buffer_set(tkz, css, css_len);

        const lxb_css_syntax_token_t *token = lxb_css_syntax_token(tkz);
        while (token != NULL && token->type != LXB_CSS_SYNTAX_TOKEN__EOF)
        {
            if (token->type == LXB_CSS_SYNTAX_TOKEN_AT_KEYWORD)
            {
                const lxb_css_syntax_token_at_keyword_t *at = lxb_css_syntax_token_at_keyword(token);

                if (at->length == 6 && lexbor_str_data_ncasecmp(at->data, (const lxb_char_t *)"import", 6))
                {
                    lxb_css_syntax_token_consume(tkz);
                    token = lxb_css_syntax_token(tkz);

                    /* Skip whitespace and comments */
                    while (token != NULL && (token->type == LXB_CSS_SYNTAX_TOKEN_WHITESPACE ||
                                             token->type == LXB_CSS_SYNTAX_TOKEN_COMMENT))
                    {
                        lxb_css_syntax_token_consume(tkz);
                        token = lxb_css_syntax_token(tkz);
                    }

                    if (token == NULL)
                        break;

                    /* Case 1: @import "style.css"; or @import url(style.css); */
                    if (token->type == LXB_CSS_SYNTAX_TOKEN_STRING ||
                        token->type == LXB_CSS_SYNTAX_TOKEN_URL)
                    {
                        const lxb_css_syntax_token_string_t *str = lxb_css_syntax_token_string(token);
                        res.emplace_back(reinterpret_cast<const char *>(str->data), str->length);
                    }
                    /* Case 2: @import url("style.css"); */
                    else if (token->type == LXB_CSS_SYNTAX_TOKEN_FUNCTION)
                    {
                        const lxb_css_syntax_token_function_t *fn = lxb_css_syntax_token_function(token);
                        if (fn->length == 3 && lexbor_str_data_ncasecmp(fn->data, (const lxb_char_t *)"url", 3))
                        {
                            lxb_css_syntax_token_consume(tkz);
                            token = lxb_css_syntax_token(tkz);

                            while (token != NULL && (token->type == LXB_CSS_SYNTAX_TOKEN_WHITESPACE ||
                                                     token->type == LXB_CSS_SYNTAX_TOKEN_COMMENT))
                            {
                                lxb_css_syntax_token_consume(tkz);
                                token = lxb_css_syntax_token(tkz);
                            }

                            if (token != NULL && token->type == LXB_CSS_SYNTAX_TOKEN_STRING)
                            {
                                const lxb_css_syntax_token_string_t *str = lxb_css_syntax_token_string(token);
                                res.emplace_back(reinterpret_cast<const char *>(str->data), str->length);
                            }
                        }
                    }
                }
            }

            lxb_css_syntax_token_consume(tkz);
            token = lxb_css_syntax_token(tkz);
        }

        lxb_css_syntax_tokenizer_destroy(tkz);
        lxb_dom_document_destroy_text(style_node->owner_document, css);
        return res;
    }

    std::string AnubisSolver::chooseRedirect(std::string_view current_url, std::string_view public_url)
    {
        if (!public_url.empty() && current_url.starts_with(public_url))
        {
            auto redir_pos = current_url.find("redir=");
            if (redir_pos == std::string::npos)
            {
                throw ParseException("Redirect URL not found in current URL");
            }
            size_t i;
            for (i = redir_pos + 6; i < current_url.size(); i++)
            {
                if (current_url[i] == '&')
                    break;
            }
            return std::string(&current_url[redir_pos + 6], &current_url[i]);
        }
        else
        {
            return std::string(current_url);
        }
    }

    std::string AnubisSolver::makePassURL(std::string_view base_prefix, std::string_view id, std::string_view hash_hex_string, std::string_view nonce_decimal_string, std::string_view redirect_URL, std::string_view elapsed_ms_decimal_string)
    {
        return std::format("{}/.within.website/x/cmd/anubis/api/pass-challenge?id={}&response={}&nonce={}&redir={}&elapsedTime={}", base_prefix, id, hash_hex_string, nonce_decimal_string, redirect_URL, elapsed_ms_decimal_string);
    }

    std::string AnubisSolver::hashToHexString(const std::array<uint8_t, 32> &hash)
    {
        static constexpr char digits[] = "0123456789abcdef";
        std::string res(hash.size() * 2, '\0');
        for (size_t i = 0; i < hash.size(); i++)
        {
            res[i * 2] = digits[hash[i] >> 4];
            res[i * 2 + 1] = digits[hash[i] & 0x0f];
        }
        return res;
    }

    AnubisSolver::AnubisSolver(std::string protected_url) : protected_url(protected_url),
                                                            cookie_jar(),
                                                            fake_browser_header(
                                                                {{"User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36"},
                                                                 {"Accept", "text/html,*/*"},
                                                                 {"Accept-Encoding", "gzip"}}),
                                                            parser(),
                                                            parsebuf()
    {
    }

    cpr::Cookies AnubisSolver::accessProtectedResource(bool gpu)
    {
        auto response = cpr::Get(protected_url, fake_browser_header, cpr::AcceptEncoding{});
        if (response.status_code == 0)
            std::cerr << response.error.message << std::endl;
        else if (response.status_code >= 400)
        {
            std::cerr << "Error [" << response.status_code << "] making request" << std::endl;
        }
        cookie_jar = response.cookies;

        auto htmldoc = HTMLDocument(response);
        lxb_dom_node_t *prefix_text_node = htmldoc.getElementById("anubis_base_prefix", htmldoc.body())->first_child;
        lxb_dom_node_t *public_url_text_node = htmldoc.getElementById("anubis_public_url", htmldoc.body())->first_child;
        lxb_dom_node_t *blob_text_node = htmldoc.getElementById("anubis_challenge", htmldoc.body())->first_child;
        if (prefix_text_node == nullptr || public_url_text_node == nullptr || blob_text_node == nullptr)
        {
            throw ParseException("URL does not point to a page protected by an Anubis challenge");
        }
        if (prefix_text_node->type != LXB_DOM_NODE_TYPE_TEXT || public_url_text_node->type != LXB_DOM_NODE_TYPE_TEXT || blob_text_node->type != LXB_DOM_NODE_TYPE_TEXT)
        {
            throw ParseException("Anubis settings found but not in expected <script> element");
        }

        std::string_view prefix = getStringFromTextNode(prefix_text_node);
        std::string_view public_url = getStringFromTextNode(public_url_text_node);
        parseChallengeSpecFromTextNode(blob_text_node);

        for (auto &extension : challenge_specification.challenge.extensions)
        {
            if (extension == "css-load")
            {
                lxb_dom_collection_t *style_elems = htmldoc.getElementsByTag("style", htmldoc.head());
                size_t count = lxb_dom_collection_length(style_elems);
                for (size_t i = 0; i < count; i++)
                {
                    lxb_dom_node_t *node = lxb_dom_collection_node(style_elems, i);
                    std::vector<std::string> urls = extractStyleImportURLs(node);
                    for (std::string &url : urls)
                    {
                        cpr::Get(cpr::Url{url}, fake_browser_header, cpr::AcceptEncoding{});
                    }
                }
            }
            else
            {
                throw ParseException(std::format("Unknown extension: {}", extension));
            }
        }

        std::string pass_url;
        switch (challenge_specification.rules.algorithm)
        {
        case Algorithm::fast:
        case Algorithm::slow:
        {
            const auto t0 = std::chrono::high_resolution_clock::now();
            auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t *>(challenge_specification.challenge.randomData.data()), challenge_specification.challenge.randomData.size());
            std::optional<AnubisResult> result;
            if (gpu)
            {
                result = do_anubis_js_gpu(seed_span, UINT64_MAX, challenge_specification.challenge.difficulty);
            }
            else
            {
                result = do_anubis_js_singlethreaded_cpu(seed_span, UINT64_MAX, challenge_specification.challenge.difficulty);
            }
            const auto t1 = std::chrono::high_resolution_clock::now();
            int64_t solveTime = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
            if (!result.has_value())
            {
                std::cerr << "Unable to find a nonce that satisfies the difficulty requirements" << std::endl;
                break;
            }
            std::string solveTimeString = std::to_string(solveTime);
            std::string hashHexString = hashToHexString(result.value().hash);
            std::string nonceDecString = std::to_string(result.value().nonce);
            pass_url = makePassURL(prefix, challenge_specification.challenge.id, hashHexString, nonceDecString, chooseRedirect(protected_url.str(), public_url), solveTimeString);
            break;
        }
        case Algorithm::sha256:
        {
            const auto t0 = std::chrono::high_resolution_clock::now();
            auto seed_span = std::span<uint8_t>(reinterpret_cast<uint8_t *>(challenge_specification.challenge.randomData.data()), challenge_specification.challenge.randomData.size());
            std::optional<AnubisResult> result;
            if (gpu)
            {
                result = do_anubis_wasm_gpu(seed_span, UINT32_MAX, challenge_specification.challenge.difficulty);
            }
            else
            {
                result = do_anubis_wasm_singlethreaded_cpu(seed_span, UINT32_MAX, challenge_specification.challenge.difficulty);
            }
            const auto t1 = std::chrono::high_resolution_clock::now();
            int64_t solveTime = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
            if (!result.has_value())
            {
                std::cerr << "Unable to find a nonce that satisfies the difficulty requirements" << std::endl;
                break;
            }
            std::string solveTimeString = std::to_string(solveTime);
            std::string hashHexString = hashToHexString(result.value().hash);
            std::string nonceDecString = std::to_string(result.value().nonce);
            pass_url = makePassURL(prefix, challenge_specification.challenge.id, hashHexString, nonceDecString, chooseRedirect(protected_url.str(), public_url), solveTimeString);
            break;
        }
        default:
            throw std::runtime_error("Unsupported Algorithm");
        }

        auto passResponse = cpr::Get(cpr::Url{pass_url}, cookie_jar, fake_browser_header);
        return passResponse.cookies;
    };
}
