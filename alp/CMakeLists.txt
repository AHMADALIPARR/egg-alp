cmake_minimum_required(VERSION 3.20)
project(alp_graphblas VERSION 0.1.0 LANGUAGES CXX)

option(ALP_GRAPHBLAS_ENABLE "Build the ALP/GraphBLAS backend" ON)
set(ALP_ROOT "" CACHE PATH "Root of an ALP/GraphBLAS installation or source tree")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
include(CTest)

add_library(alp_logic
    src/term.cpp src/atom.cpp src/unification.cpp src/knowledge_base.cpp src/inference.cpp
    src/integrity.cpp src/abduction.cpp src/model.cpp src/parser.cpp
)
target_include_directories(alp_logic PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(alp_logic PUBLIC cxx_std_20)
target_compile_options(alp_logic PRIVATE -Wall -Wextra -Wpedantic)

if(ALP_GRAPHBLAS_ENABLE)
    if(NOT ALP_ROOT)
        message(FATAL_ERROR "ALP_GRAPHBLAS_ENABLE=ON requires -DALP_ROOT=/path/to/ALP")
    endif()
    find_path(ALP_GRAPHBLAS_INCLUDE_DIR graphblas.hpp
        HINTS "${ALP_ROOT}/include" "${ALP_ROOT}" REQUIRED)
    add_library(alp_graphblas_backend
        src/graph/graph.cpp src/graph/graph_index.cpp src/graph/adjacency.cpp
        src/graph/reachability.cpp src/graph/fixed_point.cpp
        src/graph/graphblas_backend.cpp src/graph/predicates.cpp src/graph/bridge.cpp
    )
    target_include_directories(alp_graphblas_backend PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include ${ALP_GRAPHBLAS_INCLUDE_DIR})
    target_link_libraries(alp_graphblas_backend PUBLIC alp_logic)
    target_compile_definitions(alp_graphblas_backend PUBLIC ALP_GRAPHBLAS_ENABLED=1)
    target_compile_options(alp_graphblas_backend PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(alp_demo src/main.cpp)
target_link_libraries(alp_demo PRIVATE alp_logic)
if(ALP_GRAPHBLAS_ENABLE)
    target_link_libraries(alp_demo PRIVATE alp_graphblas_backend)
endif()

enable_testing()
add_executable(alp_tests tests/test_main.cpp)
target_link_libraries(alp_tests PRIVATE alp_logic)
if(ALP_GRAPHBLAS_ENABLE)
    target_link_libraries(alp_tests PRIVATE alp_graphblas_backend)
endif()
add_test(NAME alp_tests COMMAND alp_tests)
if(ALP_GRAPHBLAS_ENABLE)
    add_executable(alp_graphblas_tests tests/graphblas_test.cpp)
    target_link_libraries(alp_graphblas_tests PRIVATE alp_graphblas_backend)
    add_test(NAME alp_graphblas_tests COMMAND alp_graphblas_tests)
endif()
