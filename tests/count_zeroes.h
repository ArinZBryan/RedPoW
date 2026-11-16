#pragma once
#include <span>
#include <cstdint>
#include <cstdlib>

uint hash_countl_zero(std::span<const uint8_t, 32> hash);