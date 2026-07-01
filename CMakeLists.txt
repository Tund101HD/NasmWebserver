# Windows / WSL: add a WSL toolchain in CLion (Settings → Build → Toolchains → WSL)
# and set it as the active toolchain for this project, or use the NASM Run
# Configuration (right-click main.nasm → Run) for a zero-setup build.

cmake_minimum_required(VERSION 3.20)
# C is enabled alongside ASM_NASM so the gcc link rule (CMAKE_C_LINK_EXECUTABLE)
# exists — the executable below links with LINKER_LANGUAGE C.
project(AssemblyWebserver ASM_NASM C)

# Debug builds carry DWARF symbols for source-level stepping in GDB.
# Release builds stay clean — no debug info, suitable for distribution.
set(CMAKE_ASM_NASM_FLAGS_DEBUG   "-g -F dwarf")
set(CMAKE_ASM_NASM_FLAGS_RELEASE "")

set(CMAKE_ASM_NASM_COMPILE_OBJECT
    "<CMAKE_ASM_NASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>")

# All .nasm files in this directory are assembled and linked together, so
# multi-file projects (cross-file extern/global) just work. CONFIGURE_DEPENDS
# re-globs on build, so adding a file doesn't need a manual CMake reload.
file(GLOB NASM_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.nasm")
add_executable(AssemblyWebserver ${NASM_SOURCES})
set_target_properties(AssemblyWebserver PROPERTIES LINKER_LANGUAGE C)
target_compile_options(AssemblyWebserver PRIVATE -f elf64)
set_target_properties(AssemblyWebserver PROPERTIES LINK_FLAGS "-nostdlib -no-pie")
