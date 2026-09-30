set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# The buildenv only feeds release AppImage builds; skipping the debug
# configuration halves the build time and avoids the qtdeclarative debug
# build exhausting the runners' memory (OOM, exit 137).
set(VCPKG_BUILD_TYPE release)

# glib must be shared to avoid constructor ordering crash when
# statically linked alongside FFmpeg via LINK_GROUP:RESCAN.
if(PORT MATCHES "glib")
    set(VCPKG_LIBRARY_LINKAGE dynamic)
endif()