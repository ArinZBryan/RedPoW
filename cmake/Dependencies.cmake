# Third-party dependencies for RedPoW.
#
#   cpr     - HTTP client, pulled in with FetchContent and built as part of
#             this project. Target: cpr::cpr
#   lexbor  - HTML parser, built from source as an ExternalProject and
#             installed into the build tree. Target: lexbor::lexbor_static
#             Usage: #include <lexbor/html/parser.h>

include(FetchContent)
include(ExternalProject)

# ---------------------------------------------------------------------------
# cpr
# ---------------------------------------------------------------------------
# cpr builds its own libcurl unless told otherwise; pass
# -DCPR_USE_SYSTEM_CURL=ON to use the system libcurl (needs libcurl-devel).
set(CPR_USE_SYSTEM_CURL OFF CACHE BOOL "Use the system libcurl for cpr")
# curl >= 8.13 wants libpsl (public suffix list, used for cookie domain checks),
# which cpr builds with meson. Off by default to avoid the meson dependency;
# pass -DCPR_CURL_USE_LIBPSL=ON (and have meson or libpsl-devel) to enable it.
set(CPR_CURL_USE_LIBPSL OFF CACHE BOOL "Build curl with libpsl support")
set(CPR_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(CPR_ENABLE_SSL ON CACHE BOOL "" FORCE)

FetchContent_Declare(cpr
    GIT_REPOSITORY https://github.com/libcpr/cpr.git
    GIT_TAG 1.15.1
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(cpr)

# ---------------------------------------------------------------------------
# lexbor
# ---------------------------------------------------------------------------
set(LEXBOR_VERSION v3.0.1)
set(LEXBOR_INSTALL_DIR ${CMAKE_BINARY_DIR}/_deps/lexbor-install)
set(LEXBOR_INCLUDE_DIR ${LEXBOR_INSTALL_DIR}/include)
set(LEXBOR_STATIC_LIB
    ${LEXBOR_INSTALL_DIR}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}lexbor_static${CMAKE_STATIC_LIBRARY_SUFFIX})

ExternalProject_Add(lexbor_external
    GIT_REPOSITORY https://github.com/lexbor/lexbor.git
    GIT_TAG ${LEXBOR_VERSION}
    GIT_SHALLOW TRUE
    PREFIX ${CMAKE_BINARY_DIR}/_deps/lexbor
    INSTALL_DIR ${LEXBOR_INSTALL_DIR}
    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
        -DCMAKE_INSTALL_LIBDIR=lib
        -DCMAKE_INSTALL_INCLUDEDIR=include
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DLEXBOR_BUILD_SHARED=OFF
        -DLEXBOR_BUILD_STATIC=ON
        -DLEXBOR_BUILD_TESTS=OFF
        -DLEXBOR_BUILD_EXAMPLES=OFF
        -DLEXBOR_INSTALL_HEADERS=ON
    BUILD_BYPRODUCTS ${LEXBOR_STATIC_LIB}
    UPDATE_DISCONNECTED TRUE
)

# The include directory must exist at configure time for the imported target.
file(MAKE_DIRECTORY ${LEXBOR_INCLUDE_DIR})

add_library(lexbor::lexbor_static STATIC IMPORTED GLOBAL)
set_target_properties(lexbor::lexbor_static PROPERTIES
    IMPORTED_LOCATION ${LEXBOR_STATIC_LIB}
    INTERFACE_INCLUDE_DIRECTORIES ${LEXBOR_INCLUDE_DIR}
    INTERFACE_COMPILE_DEFINITIONS LEXBOR_STATIC
)
add_dependencies(lexbor::lexbor_static lexbor_external)
