cmake_minimum_required(VERSION 3.24)
project(RedPoW VERSION 0.1.0 LANGUAGES C CXX CUDA)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 20)
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

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cu
)
file(GLOB_RECURSE HEADERS CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cuh
)

# Everything except main.cu goes into a library so the tests can link against it.
set(LIB_SOURCES ${SOURCES})
list(FILTER LIB_SOURCES EXCLUDE REGEX "/src/main\\.cu$")

add_library(RedPoWCore STATIC ${LIB_SOURCES} ${HEADERS})
target_include_directories(RedPoWCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(RedPoWCore PUBLIC CUDA::cudart)

add_executable(RedPoW ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cu)
target_link_libraries(RedPoW PRIVATE RedPoWCore)

foreach(tgt RedPoWCore RedPoW)
    set_target_properties(${tgt} PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
    )
    target_compile_options(${tgt} PRIVATE
        $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr -lineinfo>
        $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:Debug>>:-G>
    )
endforeach()

# Unit tests (Catch2). Add test files as tests/*.cpp or tests/*.cu.
# Disable with -DREDPOW_BUILD_TESTS=OFF.
option(REDPOW_BUILD_TESTS "Build the Catch2 unit tests" ON)
if(REDPOW_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
