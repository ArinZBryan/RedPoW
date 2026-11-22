# Redteam

A CUDA implemntation of the client code for the Anubis and mCaptcha libraries, designed to defeat their protections as quickly as possible.

Built as part of an investigation into the security provided by the Anubis and mCaptcha PoW schemes for the Univerisy of Southampton's COMP3226 Group Cybersecurity research task. 


## Dependencies

Fetched and built automatically by CMake (see `cmake/Dependencies.cmake`):

- **[cpr](https://github.com/libcpr/cpr)** 1.15.1 (HTTP client), via `FetchContent`. It builds its own libcurl; configure with `-DCPR_USE_SYSTEM_CURL=ON` to use the system one instead. curl's libpsl support is off by default because it needs meson; turn it on with `-DCPR_CURL_USE_LIBPSL=ON`.
- **[lexbor](https://github.com/lexbor/lexbor)** v3.0.1 (HTML parser), built from source as an `ExternalProject` and installed into `build/_deps/lexbor-install`. Include its headers as `#include <lexbor/html/parser.h>`.

Both are linked into `RedPoWCore`, so the main executable and the tests can use them.
