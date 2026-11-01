#include <cuda_device_runtime_api.h>
#include <iostream>
#include <format>

int main(int argc, char** argv){
    if (argc < 2) { std::cerr << "Missing required argument: seed [string]"; return 1; }
    std::string seedstr = std::string(argv[1], argv[1] + strlen(argv[1]));

    

}
