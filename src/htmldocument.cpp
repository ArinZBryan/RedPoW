#include <htmldocument.h>

HTMLDocument::HTMLDocument(std::string text) : html_text(text), document(nullptr), status() {
    document = lxb_html_document_create();
    if (document == nullptr) { throw Exception("Failed to create HTML document"); }
    status = lxb_html_document_parse(document, reinterpret_cast<const lxb_char_t*>(html_text.c_str()), html_text.size());
    if (status != LXB_STATUS_OK) { throw Exception("Failed to parse HTML document"); }
}
HTMLDocument::HTMLDocument(cpr::Response res) : html_text(), document(nullptr), status() {
    if (!res.header.contains("Content-Type")) { throw Exception("Response does not set 'Content-Type' header"); }
    if (!res.header["Content-Type"].starts_with("text/html")) { throw Exception("Response does not contain HTML text"); }
    html_text = res.text;
    document = lxb_html_document_create();
    if (document == nullptr) { throw Exception("Failed to create HTML document"); }
    status = lxb_html_document_parse(document, reinterpret_cast<const lxb_char_t*>(html_text.c_str()), html_text.size());
    if (status != LXB_STATUS_OK) { throw Exception("Failed to parse HTML document"); }
}
HTMLDocument::~HTMLDocument() {
    lxb_html_document_destroy(document);
}
lxb_dom_node_t* HTMLDocument::body() {
    return reinterpret_cast<lxb_dom_node_t*>(document->body);
}
lxb_dom_node_t* HTMLDocument::head() {
    return reinterpret_cast<lxb_dom_node_t*>(document->head);
}
lxb_dom_node_t* HTMLDocument::getElementById(const std::string& id, lxb_dom_node_t* section) {
    return lxb_dom_node_by_id(section, reinterpret_cast<const lxb_char_t*>(id.c_str()), id.size());
}
lxb_dom_collection_t* HTMLDocument::getElementsByTag(const std::string& tag, lxb_dom_node_t* section) {
    lxb_dom_collection_t* col = lxb_dom_collection_make(&document->dom_document, 16);
    lxb_dom_elements_by_tag_name(lxb_dom_interface_element(section), col, reinterpret_cast<const lxb_char_t*>(tag.c_str()), tag.size());
    return col;
}
