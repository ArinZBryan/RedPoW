cmake_minimum_required(VERSION 3.24)
project(RedPoW VERSION 0.1.0 LANGUAGES C CXX CUDA)

# Fix for CMake 4.3 not having bindings for CMAKE_CUDA_STANDARD 23
# Hopefully this can be removed on higher CMake versions
if(CMAKE_CUDA_COMPILER_ID STREQUAL "NVIDIA" AND CMAKE_CUDA_COMPILER_VERSION VERSION_GREATER_EQUAL "13.3")
    set(CMAKE_CUDA23_STANDARD_COMPILE_OPTION "-std=c++23")
    set(CMAKE_CUDA23_EXTENSION_COMPILE_OPTION "-std=c++23")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 23)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Build for the GPU in this machine unless an architecture is given explicitly,
# e.g. cmake -DCMAKE_CUDA_ARCHITECTURES=86 ..
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
    set(CMAKE_CUDA_ARCHITECTURES native)
endif()

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

find_package(CUDAToolkit REQUIRED)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Dependencies.cmake)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cu
)
file(GLOB_RECURSE HEADERS CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cuh
)

# Everything except main.cpp goes into a library so the tests can link against it.
set(LIB_SOURCES ${SOURCES})
list(FILTER LIB_SOURCES EXCLUDE REGEX "/src/main\\.cpp$")

add_library(RedPoWCore STATIC ${LIB_SOURCES} ${HEADERS})
target_include_directories(RedPoWCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(RedPoWCore PUBLIC CUDA::cudart cpr::cpr lexbor::lexbor_static)

add_executable(RedPoW ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp)
target_link_libraries(RedPoW PRIVATE RedPoWCore)

foreach(tgt RedPoWCore RedPoW)
    set_target_properties(${tgt} PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
    )
    target_compile_options(${tgt} PRIVATE
        $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>
        # -G (full device debug info) and -lineinfo conflict, so pick one per config.
        $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:Debug>>:-G>
        $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<NOT:$<CONFIG:Debug>>>:-lineinfo>
    )
endforeach()

# Unit tests (Catch2). Add test files as tests/*.cpp or tests/*.cu.
# Disable with -DREDPOW_BUILD_TESTS=OFF.
option(REDPOW_BUILD_TESTS "Build the Catch2 unit tests" ON)
if(REDPOW_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
