cmake_minimum_required(VERSION 3.10.2)

project(void_lex_native)

add_library(
    xray_process
    SHARED
    xray_process.cpp
)

target_compile_features(xray_process PRIVATE cxx_std_17)
