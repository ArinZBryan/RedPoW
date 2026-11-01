#pragma once

#define THREAD_INDEX_IN_BLOCK_1D (static_cast<size_t>(threadIdx.x))
#define THREAD_COUNT_IN_BLOCK_1D (static_cast<size_t>(blockDim.x))
#define THREAD_INDEX_IN_BLOCK_3D (static_cast<size_t>(threadIdx.x) + static_cast<size_t>(blockDim.y) * (static_cast<size_t>(threadIdx.y) + static_cast<size_t>(blockDim.z) * static_cast<size_t>(threadIdx.z)))
#define THREAD_COUNT_IN_BLOCK_3D (static_cast<size_t>(blockDim.x) * static_cast<size_t>(blockDim.y) * static_cast<size_t>(blockDim.z))
#define BLOCK_INDEX_IN_GRID_1D (static_cast<size_t>(blockIdx.x))
#define BLOCK_COUNT_IN_GRID_1D (static_cast<size_t>(gridDim.x))
#define BLOCK_INDEX_IN_GRID_3D (static_cast<size_t>(blockIdx.x) * static_cast<size_t>(gridDim.y) * (static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.z) * static_cast<size_t>(blockIdx.z)))
#define BLOCK_COUNT_IN_GRID_3D (static_cast<size_t>(gridDim.x) * static_cast<size_t>(gridDim.y) * static_cast<size_t>(gridDim.z))
#define THREAD_INDEX_IN_GRID_1D (THREAD_INDEX_IN_BLOCK_1D + THREAD_COUNT_IN_BLOCK_1D * BLOCK_INDEX_IN_GRID_1D)
#define THREAD_COUNT_IN_GRID_1D (THREAD_COUNT_IN_BLOCK_1D * BLOCK_COUNT_IN_GRID_1D)
#define THREAD_INDEX_IN_GRID_3D (THREAD_INDEX_IN_BLOCK_3D + THREAD_COUNT_IN_BLOCK_3D * BLOCK_INDEX_IN_GRID_3D)
#define THREAD_COUNT_IN_GRID_3D (THREAD_COUNT_IN_BLOCK_3D * BLOCK_COUNT_IN_GRID_3D)
#define THREAD_COUNT_1D THREAD_COUNT_IN_GRID_1D
#define THREAD_COUNT_3D THREAD_COUNT_IN_GRID_3D
#define THREAD_ID_1D THREAD_INDEX_IN_GRID_1D
#define THREAD_ID_3D THREAD_INDEX_IN_GRID_3D

