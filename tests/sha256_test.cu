#include <catch2/catch_test_macros.hpp>
#include <cuda/std/span>
#include <cuda_device_runtime_api.h>
#include <sha256.cuh>

bool sha256stateseq(const struct sha256state& a, const struct sha256state& b) {
    return (
        a.a == b.a &&
        a.b == b.b &&
        a.c == b.c &&
        a.d == b.d &&
        a.e == b.e &&
        a.f == b.f &&
        a.g == b.g &&
        a.h == b.h
    );
}

TEST_CASE("Sha256 Implementation is correct", "[sha256]") {
    SECTION("Hashing one message") {
        uint8_t* data_ptr = nullptr;
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&data_ptr, 1);
        cudaMallocManaged(&state_ptr, sizeof(sha256state));
        cuda::std::span<uint8_t, 1>* datas_ptr = nullptr;
        cudaMallocManaged(&datas_ptr, sizeof(*datas_ptr));

        cuda::std::span<uint8_t, 1> data = cuda::std::span<uint8_t, 1>(data_ptr, 1);
        data[0] = 0;
        *datas_ptr = data;
        auto datas = cuda::std::span<const cuda::std::span<uint8_t, 1>>(datas_ptr, 1);

        auto states = cuda::std::span<struct sha256state>(state_ptr, 1);

        sha256_hash<1><<<1, 1>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        struct sha256state correct = {
            0x6e340b9c,
            0xffb37a98,
            0x9ca544e6,
            0xbb780a2c,
            0x78901d3f,
            0xb3373876,
            0x8511a306,
            0x17afa01d
        };


        REQUIRE(sha256stateseq(correct, states[0]));

        cudaFree(datas_ptr);
        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }
}