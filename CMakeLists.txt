# The Nintendo 3DS build (devkitARM's 3DS.cmake); the desktop builds with build.sh.
# build.sh lifts first (src/gen) and extracts work/; then, in devkitpro/devkitarm:
#   cmake -B build-3ds -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/cmake/3DS.cmake -DCMAKE_BUILD_TYPE=Release
#   cmake --build build-3ds
# and copy build-3ds/shufflepuck.3dsx, work/unpacked, work/rsrc and work/data_fork.bin to
# sdmc:/3ds/shufflepuck/ (the .3dsx beside a work/ folder).
cmake_minimum_required(VERSION 3.20)
project(shufflepuck C)
if(NOT NINTENDO_3DS)
  message(FATAL_ERROR "CMake builds the 3DS port only; the desktop builds with build.sh")
endif()
file(GLOB GEN ${CMAKE_SOURCE_DIR}/src/gen/code_*.c)
if(NOT GEN)
  message(FATAL_ERROR "src/gen is empty: run build.sh first (it lifts the game from your disk image)")
endif()
set(MR ${CMAKE_SOURCE_DIR}/ext/macrecomp)
add_executable(shufflepuck src/main.c ${GEN}
  ${MR}/runtime/m68k.c ${MR}/runtime/quickdraw.c ${MR}/runtime/toolbox.c ${MR}/runtime/platform_3ds.c
  ${MR}/runtime/dialog.c ${MR}/runtime/files.c ${MR}/runtime/textedit.c)
set_source_files_properties(${GEN} PROPERTIES COMPILE_OPTIONS "-w;-fno-strict-aliasing;-fwrapv")
target_compile_options(shufflepuck PRIVATE -O2 -std=gnu11)
target_compile_definitions(shufflepuck PRIVATE MACRECOMP_NO_TRAP_STUB)
target_include_directories(shufflepuck PRIVATE ${MR}/include)
target_link_libraries(shufflepuck PRIVATE ctru m)
ctr_generate_smdh(shufflepuck.smdh NAME "Shufflepuck Cafe" DESCRIPTION "Broderbund, 1988; recompiled" AUTHOR "macrecomp")
ctr_create_3dsx(shufflepuck SMDH shufflepuck.smdh)
