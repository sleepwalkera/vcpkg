#!/usr/bin/env bash
# Check that every host tool under <dir> only needs glibc/GLIBCXX version nodes
# the build host provides.
#
# The linux buildenv jobs run on the ubuntu-22.04 AppImage floor. Host tools
# restored from the NuGet binary cache may have been built on a newer host and
# require a newer glibc, which would fail as soon as the AppImage build invokes
# them. The acceptable versions are taken from this host's own libc and
# libstdc++ (located via ldconfig), so the floor follows the host and needs no
# hardcoded values.
#
# Usage: check_buildenv_floor.sh <dir>
# Walks <dir>, inspects ELF files, exits non-zero on any glibc/GLIBCXX node the
# host does not provide.

set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <dir>" >&2; exit 2; }
dir="$1"
[ -d "$dir" ] || exit 0

ldconfig_cmd=""
for c in "$(command -v ldconfig 2>/dev/null)" /usr/sbin/ldconfig /sbin/ldconfig; do
    [ -n "$c" ] && [ -x "$c" ] && { ldconfig_cmd="$c"; break; }
done
[ -n "$ldconfig_cmd" ] || { echo "cannot locate ldconfig" >&2; exit 2; }

libc=$("$ldconfig_cmd" -p | awk '/libc\.so\.6$/ {print $NF; exit}')
libstdcpp=$("$ldconfig_cmd" -p | awk '/libstdc\+\+\.so\.6$/ {print $NF; exit}')
[ -n "$libc" ] && [ -n "$libstdcpp" ] || { echo "cannot locate host libc/libstdc++" >&2; exit 2; }

# Version-provided maps: GLIBC_*/GLIBCXX_* nodes the host ships.
declare -A prov
while IFS= read -r node; do
    [ -n "$node" ] && prov["$node"]=1
done < <(readelf --version-info "$libc" 2>/dev/null \
    | sed -n 's/.*Name: \(GLIBC\)_\([0-9.]*\).*/\1_\2/p' \
    | sort -u)
while IFS= read -r node; do
    [ -n "$node" ] && prov["$node"]=1
done < <(readelf --version-info "$libstdcpp" 2>/dev/null \
    | sed -n 's/.*Name: \(GLIBCXX\)_\([0-9.]*\).*/\1_\2/p' \
    | sort -u)

fail=0
while IFS= read -r -d '' f; do
    file "$f" | grep -q 'ELF' || continue
    reqs=$(readelf --version-info "$f" 2>/dev/null \
        | sed -n 's/.*Name: \(GLIBC\|GLIBCXX\)_\([0-9.]*\).*/\1_\2/p' || true)
    while read -r node; do
        [ -n "$node" ] || continue
        if [ -z "${prov[$node]+1}" ]; then
            echo "floor violation: $f requires $node, the host does not provide it" >&2
            fail=1
        fi
    done <<< "$reqs"
done < <(find "$dir" -type f -print0)

if [ "$fail" != 0 ]; then
    echo "restored host tools require a newer glibc/GLIBCXX than this host provides" >&2
    exit 1
fi
echo "$dir: host tools meet this host's ABI floor"