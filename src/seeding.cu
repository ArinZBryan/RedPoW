#include <seeding.cuh>
#include <cuda/std/span>

__device__ void shr_uint128_t(cuda::std::span<uint32_t, 4> out, size_t n) {
    size_t bits_to_shift_by = n * 8;
    out[0] = __funnelshift_r(out[0], 0,      bits_to_shift_by);
    out[1] = __funnelshift_r(out[1], out[0], bits_to_shift_by);
    out[2] = __funnelshift_r(out[2], out[1], bits_to_shift_by);
    out[3] = __funnelshift_r(out[3], out[2], bits_to_shift_by);
}