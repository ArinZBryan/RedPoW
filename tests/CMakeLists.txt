find_package(Catch2 3 QUIET)
if(NOT Catch2_FOUND)
    include(FetchContent)
    FetchContent_Declare(Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.7.1
    )
    FetchContent_MakeAvailable(Catch2)
    list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)
endif()

file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cu
)

add_executable(RedPoWTests ${TEST_SOURCES})
target_link_libraries(RedPoWTests PRIVATE RedPoWCore Catch2::Catch2WithMain)
target_include_directories(RedPoWTests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

set_target_properties(RedPoWTests PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
    CUDA_RESOLVE_DEVICE_SYMBOLS ON
)
target_compile_options(RedPoWTests PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr -lineinfo>
)

include(Catch)
catch_discover_tests(RedPoWTests)
