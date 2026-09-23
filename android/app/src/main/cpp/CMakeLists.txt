cmake_minimum_required(VERSION 3.18.1)
project(awy_llama C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Disable unnecessary llama.cpp features and targets for mobile compatibility
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "Build llama.cpp examples" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "Build llama.cpp tests" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "Build llama.cpp server" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build llama static libraries" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "Disable llamafile feature" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "Disable OpenMP for mobile threading" FORCE)

add_subdirectory(llama_cpp_src)

add_library(awy_llama SHARED awy_jni.cpp)

target_include_directories(awy_llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/llama_cpp_src/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama_cpp_src/ggml/include
)

target_link_libraries(awy_llama
    llama
    ggml
    log
)
