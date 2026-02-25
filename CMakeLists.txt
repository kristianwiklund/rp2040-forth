# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.2.0)
set(toolchainVersion 14_2_Rel1)
set(picotoolVersion 2.2.0-a4)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD pico CACHE STRING "Board type")

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

