#include <catch2/catch_test_macros.hpp>
#include <cstring>
#include <cuda/std/span>
#include <vendor/bitcoin/crypto/sha256.h>
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

    SECTION("Hashing two messages with spans") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x1)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        // Allocate the actual buffer for the spans pointing to the data
        cuda::std::span<uint8_t, 1>* datas_ptr = nullptr;
        cudaMallocManaged(&datas_ptr, num_messages * sizeof(*datas_ptr));

        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas_ptr[msg_no] = cuda::std::span<uint8_t, 1>(data_ptr + msg_no, 1);
            datas_ptr[msg_no][0] = static_cast<uint8_t>(msg_no);            
        }

        auto datas = cuda::std::span<const cuda::std::span<uint8_t, 1>>(datas_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<1><<<1, 1>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(datas_ptr);
        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing two messages with mdspan") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x1)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        
        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);            
        }

        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<1><<<1, 1>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing two larger messages with mdspan") {
        constexpr size_t num_messages = 2;

        // hashes from https://pi7.org/hash/sha256
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0000)
                0x96a296d2,
                0x24f285c6,
                0x7bee93c3,
                0x0f8a3091,
                0x57f0daa3,
                0x5dc5b87e,
                0x410b7863,
                0x0a09cfc7,
            },
            {                               // sha256(0x0001)
                0xb413f47d,
                0x13ee2fe6,
                0xc845b2ee,
                0x141af81d,
                0xe858df4e,
                0xc549a58b,
                0x7970bb96,
                0x645bc8d2,
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * 2 * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 2>>(data_ptr, num_messages);
        
        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            // little endian?
            datas(msg_no, 0) = static_cast<uint8_t>(0);
            datas(msg_no, 1) = static_cast<uint8_t>(msg_no);            
        }

        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<2><<<1, 1>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing two messages with spans using two threads") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x1)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        // Allocate the actual buffer for the spans pointing to the data
        cuda::std::span<uint8_t, 1>* datas_ptr = nullptr;
        cudaMallocManaged(&datas_ptr, num_messages * sizeof(*datas_ptr));

        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas_ptr[msg_no] = cuda::std::span<uint8_t, 1>(data_ptr + msg_no, 1);
            datas_ptr[msg_no][0] = static_cast<uint8_t>(msg_no);            
        }

        auto datas = cuda::std::span<const cuda::std::span<uint8_t, 1>>(datas_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<1><<<1, 2>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(datas_ptr);
        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing two messages with mdspan using two threads") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x1)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        
        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);            
        }

        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<1><<<1, 2>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing two larger messages with mdspan using two threads") {
        constexpr size_t num_messages = 2;

        // hashes from https://pi7.org/hash/sha256
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x0000)
                0x96a296d2,
                0x24f285c6,
                0x7bee93c3,
                0x0f8a3091,
                0x57f0daa3,
                0x5dc5b87e,
                0x410b7863,
                0x0a09cfc7,
            },
            {                               // sha256(0x0001)
                0xb413f47d,
                0x13ee2fe6,
                0xc845b2ee,
                0x141af81d,
                0xe858df4e,
                0xc549a58b,
                0x7970bb96,
                0x645bc8d2,
            }
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * 2 * sizeof(uint8_t));
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 2>>(data_ptr, num_messages);
        
        // Fill up the buffers of spans and the data to go inside
        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            // little endian?
            datas(msg_no, 0) = static_cast<uint8_t>(0);
            datas(msg_no, 1) = static_cast<uint8_t>(msg_no);            
        }

        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        sha256_hash<2><<<1, 2>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Hashing a much larger message with mdspan") {

        /*Taken from https://en.wikipedia.org/wiki/Sovetsky_Soyuz-class_battleship*/
        const char message[] = 
            "The Sovetsky Soyuz-class battleships (Project 23, Russian: Советский Союз, "
            "\'Soviet Union\'), also known as \"Stalin\'s Republics\", were a class of "
            "battleships begun by the Soviet Union in the late 1930s but never brought "
            "into service. They were designed in response to the Bismarck-class battleships "
            "being built by Germany.\nThese ships would have rivaled the Imperial Japanese "
            "Yamato class and America\'s planned Montana class in size if any had been "
            "completed, although with significantly weaker firepower: nine 406-millimeter "
            "(16 in) guns compared to the nine 460-millimeter (18.1 in) guns of the Japanese "
            "ships and a dozen 16-inch (406 mm) on the Montanas. The failure of the Soviet "
            "armor plate industry to build cemented armor plates thicker than 230 millimeters "
            "(9.1 in) would have negated any combat advantages from the Sovetsky Soyuz "
            "class\'s thicker armor.\nConstruction of the first four ships was plagued "
            "with difficulties as the Soviet shipbuilding and related industries were not "
            "prepared to build such large ships. One battleship, Sovetskaya Belorussiya, was "
            "cancelled on 19 October 1940 after serious construction flaws were found. "
            "Construction of the other three ships was suspended shortly after Nazi Germany "
            "invaded the Soviet Union in June 1941, and never resumed. All three of the "
            "surviving hulls were scrapped in the late 1940s.";

        // Length excludes the string literal's trailing NUL
        constexpr size_t message_len = sizeof(message) - 1;

        // Reference hash computed with Python's hashlib.sha256 over the UTF-8 bytes above
        constexpr struct sha256state correct = {
            0xc60353ca,
            0x54e48c2d,
            0xef7376bf,
            0x8981a4b3,
            0xbf840329,
            0x60a5e09e,
            0xaf161835,
            0xbf53231b
        };


        // Allocate the actual buffer for the data
        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, message_len);
        
        // Allocate the actual buffer for the states
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, message_len>>(data_ptr, 1);
        cudaMemcpy(data_ptr, message, message_len, cudaMemcpyDefault);
         
        auto states = cuda::std::span<struct sha256state>(state_ptr, 1);

        sha256_hash<message_len><<<1, 1>>>(datas, states);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        REQUIRE(sha256stateseq(correct, states[0]));
        
        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }
};


// Host-side copy of the SHA256 initial hash values (`initial_hash_state` is __constant__, so device-only)
constexpr struct sha256state host_initial_hash_state = {
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19
};

// Runs `len` bytes (a whole number of 64 byte chunks) through the vendored bitcoin SHA256 and returns the midstate,
// i.e. the state that sha256_hash_partial should continue hashing from
struct sha256state sha256_midstate(const uint8_t* prefix, size_t len) {
    REQUIRE(len % 64 == 0);
    CSHA256 hasher;
    hasher.Write(reinterpret_cast<const unsigned char*>(prefix), len);
    struct sha256state s;
    static_assert(sizeof(s) == sizeof(hasher.s));
    std::memcpy(&s, hasher.s, sizeof(s));
    return s;
}

// Expected hashes generated with `python3 poc.py -H -s -x -d <hex data>`, where P64 is the 64 bytes 0x00..0x3f
// and P128 is the 128 bytes 0x00..0x7f
TEST_CASE("Partial SHA256 Implementation is correct", "[sha256]") {
    SECTION("Partially hashing one message from the initial state") {
        // sha256(0x00)
        constexpr struct sha256state correct = {
            0x6e340b9c,
            0xffb37a98,
            0x9ca544e6,
            0xbb780a2c,
            0x78901d3f,
            0xb3373876,
            0x8511a306,
            0x17afa01d
        };

        uint8_t* data_ptr = nullptr;
        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&data_ptr, 1);
        cudaMallocManaged(&state_ptr, sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, 1);
        datas(0, 0) = 0;

        auto states = cuda::std::span<struct sha256state>(state_ptr, 1);
        states[0] = host_initial_hash_state;

        sha256_hash_partial<1><<<1, 1>>>(datas, states, 0);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        REQUIRE(sha256stateseq(correct, states[0]));

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two messages from the initial state") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x00)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x01)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);
            states[msg_no] = host_initial_hash_state;
        }

        sha256_hash_partial<1><<<1, 1>>>(datas, states, 0);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two messages after a one chunk prefix") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(P64 || 0x00)
                0x580e181c,
                0xedaa9a20,
                0x50f7b393,
                0x93543bd5,
                0x90e29045,
                0x4014458b,
                0x713f8282,
                0xd2148591
            },
            {                               // sha256(P64 || 0x01)
                0x063f0e4e,
                0x6060a87e,
                0x9141d2b0,
                0x80085d37,
                0x310e0ccd,
                0xc33c9823,
                0x9cc1da89,
                0xa9dbeaae
            }
        };

        uint8_t prefix[64];
        for (size_t i = 0; i < sizeof(prefix); i++) { prefix[i] = static_cast<uint8_t>(i); }
        const struct sha256state midstate = sha256_midstate(prefix, sizeof(prefix));

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);
            states[msg_no] = midstate;
        }

        sha256_hash_partial<1><<<1, 1>>>(datas, states, sizeof(prefix) * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two larger messages after a one chunk prefix") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(P64 || 0x0000)
                0x11982986,
                0xa1646de4,
                0x04661f30,
                0x225a0c02,
                0xb209e289,
                0x5e47fe3e,
                0x2a6012f2,
                0x5a31df13
            },
            {                               // sha256(P64 || 0x0001)
                0x9b9d48ec,
                0xad1aed70,
                0x9c9f643e,
                0xaecbff93,
                0xea8aca63,
                0xfeb48db1,
                0x83c5da68,
                0x319129ff
            }
        };

        uint8_t prefix[64];
        for (size_t i = 0; i < sizeof(prefix); i++) { prefix[i] = static_cast<uint8_t>(i); }
        const struct sha256state midstate = sha256_midstate(prefix, sizeof(prefix));

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * 2 * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 2>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(0);
            datas(msg_no, 1) = static_cast<uint8_t>(msg_no);
            states[msg_no] = midstate;
        }

        sha256_hash_partial<2><<<1, 1>>>(datas, states, sizeof(prefix) * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two messages from the initial state using two threads") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(0x00)
                0x6e340b9c,
                0xffb37a98,
                0x9ca544e6,
                0xbb780a2c,
                0x78901d3f,
                0xb3373876,
                0x8511a306,
                0x17afa01d
            },
            {                               // sha256(0x01)
                0x4bf5122f,
                0x344554c5,
                0x3bde2ebb,
                0x8cd2b7e3,
                0xd1600ad6,
                0x31c385a5,
                0xd7cce23c,
                0x7785459a
            }
        };

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);
            states[msg_no] = host_initial_hash_state;
        }

        sha256_hash_partial<1><<<1, 2>>>(datas, states, 0);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two messages after a one chunk prefix using two threads") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(P64 || 0x00)
                0x580e181c,
                0xedaa9a20,
                0x50f7b393,
                0x93543bd5,
                0x90e29045,
                0x4014458b,
                0x713f8282,
                0xd2148591
            },
            {                               // sha256(P64 || 0x01)
                0x063f0e4e,
                0x6060a87e,
                0x9141d2b0,
                0x80085d37,
                0x310e0ccd,
                0xc33c9823,
                0x9cc1da89,
                0xa9dbeaae
            }
        };

        uint8_t prefix[64];
        for (size_t i = 0; i < sizeof(prefix); i++) { prefix[i] = static_cast<uint8_t>(i); }
        const struct sha256state midstate = sha256_midstate(prefix, sizeof(prefix));

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 1>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);
            states[msg_no] = midstate;
        }

        sha256_hash_partial<1><<<1, 2>>>(datas, states, sizeof(prefix) * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing two larger messages after a one chunk prefix using two threads") {
        constexpr size_t num_messages = 2;
        constexpr struct sha256state correct[] = {
            {                               // sha256(P64 || 0x0000)
                0x11982986,
                0xa1646de4,
                0x04661f30,
                0x225a0c02,
                0xb209e289,
                0x5e47fe3e,
                0x2a6012f2,
                0x5a31df13
            },
            {                               // sha256(P64 || 0x0001)
                0x9b9d48ec,
                0xad1aed70,
                0x9c9f643e,
                0xaecbff93,
                0xea8aca63,
                0xfeb48db1,
                0x83c5da68,
                0x319129ff
            }
        };

        uint8_t prefix[64];
        for (size_t i = 0; i < sizeof(prefix); i++) { prefix[i] = static_cast<uint8_t>(i); }
        const struct sha256state midstate = sha256_midstate(prefix, sizeof(prefix));

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * 2 * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, 2>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(0);
            datas(msg_no, 1) = static_cast<uint8_t>(msg_no);
            states[msg_no] = midstate;
        }

        sha256_hash_partial<2><<<1, 2>>>(datas, states, sizeof(prefix) * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing messages that need two padding chunks after a two chunk prefix using two threads") {
        // A 60 byte suffix leaves no room in its chunk for the 0x80 byte and 64 bit length, so padding spills into a second chunk
        constexpr size_t num_messages = 2;
        constexpr size_t message_len = 60;
        constexpr struct sha256state correct[] = {
            {                               // sha256(P128 || 0x00 || 0x01..0x3b)
                0xb53284a2,
                0xdcdc7084,
                0x8cfd64b7,
                0x63a8da72,
                0x1151b362,
                0x7e56aa58,
                0xdd3cc7a2,
                0x410104f8
            },
            {                               // sha256(P128 || 0x01 || 0x01..0x3b)
                0x5b3b1f9f,
                0x1d640d1e,
                0x0810cdc8,
                0x56517779,
                0x81d3d65e,
                0xcd9dfc53,
                0xd901b43b,
                0x2b32ec61
            }
        };

        uint8_t prefix[128];
        for (size_t i = 0; i < sizeof(prefix); i++) { prefix[i] = static_cast<uint8_t>(i); }
        const struct sha256state midstate = sha256_midstate(prefix, sizeof(prefix));

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, num_messages * message_len * sizeof(uint8_t));

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, num_messages * sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, message_len>>(data_ptr, num_messages);
        auto states = cuda::std::span<struct sha256state>(state_ptr, num_messages);

        for (size_t msg_no = 0; msg_no < num_messages; msg_no++) {
            datas(msg_no, 0) = static_cast<uint8_t>(msg_no);
            for (size_t i = 1; i < message_len; i++) { datas(msg_no, i) = static_cast<uint8_t>(i); }
            states[msg_no] = midstate;
        }

        sha256_hash_partial<message_len><<<1, 2>>>(datas, states, sizeof(prefix) * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        for (size_t hash_no = 0; hash_no < num_messages; hash_no++) {
            REQUIRE(sha256stateseq(correct[hash_no], states[hash_no]));
        }

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }

    SECTION("Partially hashing the end of a much larger message") {

        /*Taken from https://en.wikipedia.org/wiki/Sovetsky_Soyuz-class_battleship*/
        const char message[] = 
            "The Sovetsky Soyuz-class battleships (Project 23, Russian: Советский Союз, "
            "\'Soviet Union\'), also known as \"Stalin\'s Republics\", were a class of "
            "battleships begun by the Soviet Union in the late 1930s but never brought "
            "into service. They were designed in response to the Bismarck-class battleships "
            "being built by Germany.\nThese ships would have rivaled the Imperial Japanese "
            "Yamato class and America\'s planned Montana class in size if any had been "
            "completed, although with significantly weaker firepower: nine 406-millimeter "
            "(16 in) guns compared to the nine 460-millimeter (18.1 in) guns of the Japanese "
            "ships and a dozen 16-inch (406 mm) on the Montanas. The failure of the Soviet "
            "armor plate industry to build cemented armor plates thicker than 230 millimeters "
            "(9.1 in) would have negated any combat advantages from the Sovetsky Soyuz "
            "class\'s thicker armor.\nConstruction of the first four ships was plagued "
            "with difficulties as the Soviet shipbuilding and related industries were not "
            "prepared to build such large ships. One battleship, Sovetskaya Belorussiya, was "
            "cancelled on 19 October 1940 after serious construction flaws were found. "
            "Construction of the other three ships was suspended shortly after Nazi Germany "
            "invaded the Soviet Union in June 1941, and never resumed. All three of the "
            "surviving hulls were scrapped in the late 1940s.";

        // Length excludes the string literal's trailing NUL (1355 bytes)
        constexpr size_t message_len = sizeof(message) - 1;

        // Hash the first 20 chunks on the CPU, leaving 75 bytes (a full chunk plus a partial one) for the GPU
        constexpr size_t prefix_len = 20 * 64;
        constexpr size_t suffix_len = message_len - prefix_len;
        static_assert(suffix_len > 64 && suffix_len < 128);

        // sha256 of the whole message, generated with `python3 poc.py -H -s -f <file containing the message>`
        constexpr struct sha256state correct = {
            0xc60353ca,
            0x54e48c2d,
            0xef7376bf,
            0x8981a4b3,
            0xbf840329,
            0x60a5e09e,
            0xaf161835,
            0xbf53231b
        };

        const struct sha256state midstate = sha256_midstate(reinterpret_cast<const uint8_t*>(message), prefix_len);

        uint8_t* data_ptr = nullptr;
        cudaMallocManaged(&data_ptr, suffix_len);

        struct sha256state* state_ptr = nullptr;
        cudaMallocManaged(&state_ptr, sizeof(sha256state));

        auto datas = cuda::std::mdspan<uint8_t, cuda::std::extents<size_t, cuda::std::dynamic_extent, suffix_len>>(data_ptr, 1);
        cudaMemcpy(data_ptr, message + prefix_len, suffix_len, cudaMemcpyDefault);

        auto states = cuda::std::span<struct sha256state>(state_ptr, 1);
        states[0] = midstate;

        sha256_hash_partial<suffix_len><<<1, 1>>>(datas, states, prefix_len * 8);
        REQUIRE(cudaGetLastError() == cudaSuccess);
        REQUIRE(cudaDeviceSynchronize() == cudaSuccess);

        REQUIRE(sha256stateseq(correct, states[0]));

        cudaFree(data_ptr);
        cudaFree(state_ptr);
    }
}
