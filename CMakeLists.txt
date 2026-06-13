# =============================================================================
# CMakeLists.txt — top-level CMake build configuration
# =============================================================================
#
# CMake is a "build system generator" — it does not build the code itself,
# but generates the files (Makefiles, Ninja build files, Visual Studio projects)
# that a real build tool uses.
#
# HOW TO BUILD:
#   mkdir build
#   cd build
#   cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug
#   ninja
#
# HOW TO RUN TESTS:
#   cd build && ctest --output-on-failure
#
# BUILD TYPES:
#   Debug   : includes -g (debug symbols), address sanitiser, UB sanitiser.
#             Use this during development — it catches bugs at runtime.
#   Release : includes -O3 -march=native (maximum optimisation).
#             Use this for benchmarks and production.
# =============================================================================

# cmake_minimum_required: fail with a clear message if CMake is too old.
# We need 3.16+ for target_precompile_headers and IMPORTED targets.
cmake_minimum_required(VERSION 3.16)

# project(): set the project name, version, and languages used.
# VERSION is used by CPack for packaging and by cpack_add_component.
project(
    probos_kernel
    VERSION 0.0.1
    DESCRIPTION "ProbOS: A Probabilistic Execution Runtime"
    LANGUAGES CXX
)

# C++17 is the minimum for:
#   - std::optional, std::variant, std::string_view
#   - if constexpr
#   - Structured bindings (auto [a, b] = ...)
# We use C++20 features (concepts) from Month 2 onward.
# Setting 20 here now avoids a rebuild later.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)   # OFF = strict ISO C++; ON = GNU extensions

# Put all build outputs in predictable locations inside build/
# This makes it easy to find executables and libraries.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Export a compile_commands.json file.
# This is used by clangd (the language server in VS Code) to understand
# the project structure and provide autocomplete / error checking.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Delegate all actual build targets to cpp/CMakeLists.txt.
# This keeps the top-level file clean and allows the cpp/ subtree to grow
# independently.
enable_testing()
add_subdirectory(cpp)
