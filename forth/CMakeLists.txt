cmake_minimum_required(VERSION 3.13)
include(pico_sdk_import.cmake)
project(forth_project C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
pico_sdk_init()
add_executable(forth
forth.S
)
pico_enable_stdio_uart(forth 1)
pico_add_extra_outputs(forth)
target_link_libraries(forth pico_stdlib)
