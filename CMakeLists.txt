cmake_minimum_required(VERSION 3.13)
include(pico_sdk_import.cmake)
include_directories(.)
project(forth_project C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
add_compile_options(-ffunction-sections)
pico_sdk_init()
add_executable(forth
forth.S terminal.h macros.h output.h strings.S compile.h forthdefs.h mathwords.h convert.S helpers.S 
)
pico_enable_stdio_uart(forth 1)
pico_enable_stdio_usb(forth 0)
pico_add_extra_outputs(forth)
target_link_libraries(forth pico_bootsel_via_double_reset pico_stdlib)

