#pragma once
#include <string>
#include <exception>
#include <format>
#include <vector>
#include <cpr/cpr.h>
#include <lexbor/html/parser.h>
#include <lexbor/dom/interfaces/element.h>
#include <lexbor/dom/interfaces/text.h>

class HTMLDocument {
    lxb_status_t status;
    lxb_html_document* document;
    std::string html_text;

public:
    class Exception : public std::runtime_error { using std::runtime_error::runtime_error; };

    HTMLDocument(std::string text);
    HTMLDocument(cpr::Response res);
    ~HTMLDocument();

    lxb_dom_node_t* body();
    lxb_dom_node_t* head();
    lxb_dom_node_t* getElementById(const std::string& id, lxb_dom_node_t* section);
    lxb_dom_collection_t* getElementsByTag(const std::string& tag, lxb_dom_node_t* section);
};
