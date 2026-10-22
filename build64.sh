#!/bin/bash

P=$PWD

cd $VER
mkdir -p b64
cd b64

DEP="libasound2-dev libpulse-dev libdbus-1-dev libfontconfig-dev libfreetype-dev libgnutls28-dev libssl-dev libgl-dev libunwind-dev libx11-dev libxcomposite-dev libxcursor-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev libxext-dev libwayland-bin libwayland-dev libegl-dev libwayland-dev libxkbcommon-dev libxkbregistry-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libosmesa6-dev libsdl2-dev libudev-dev libvulkan-dev libcups2-dev samba-dev ocl-icd-opencl-dev libusb-1.0-0-dev libv4l-dev"

apt install --ignore-missing -y $DEP || exit 128

export CFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export CXXFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export x86_64_CFLAGS="$CFLAGS"
export i386_CFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O3 -static-libgcc -static-libstdc++"
export LDEXECFLAGS="$LDFLAGS"

MIMALLOC_SRC="$P/mimalloc-v3.5.3"
cmake -S "$MIMALLOC_SRC" -B b64/mimalloc \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DMI_OVERRIDE=ON -DMI_BUILD_STATIC=ON -DMI_BUILD_OBJECT=ON \
  -DMI_BUILD_SHARED=OFF -DMI_BUILD_TESTS=OFF \
  -DMI_OPT_ARCH=ON -DMI_STATS=OFF -DMI_PROFILE=OFF \
  -DMI_TLS_MODEL=LOCAL_DYNAMIC || exit 128
cmake --build b64/mimalloc --target mimalloc-obj-target || exit 128
MIMALLOC_OBJ="$PWD/b64/mimalloc/mimalloc.o"
MIMALLOC_OBJ32="$(dirname "$PWD")/b32/b32/mimalloc/mimalloc.o"

# Idempotent x64 injection into a controlled declaration line of a shared
# Makefile.in template. Restores the x64 value from the original, x64, or
# i386 state; aborts (128) on a missing/duplicated declaration or an
# unexpected upstream shape, never silently dropping extra objects.
inject_decl() { # file anchor original target otherpat1 otherpat2 otherline2
  local file="$1" anchor="$2" original="$3" target="$4" pat="$5" pat2="$6" line2="$7"
  [ -f "$file" ] || { echo "inject_decl: missing $file" >&2; return 128; }
  local n
  n=$(grep -cF "$anchor" "$file" || true)
  [ "$n" = "1" ] || { echo "inject_decl: $n '$anchor' declarations in $file (want 1)" >&2; return 128; }
  grep -Fxq "$original" "$file" \
    || grep -Fxq "$target" "$file" \
    || { [ -n "$pat" ] && grep -Fxq "$pat" "$file"; } \
    || { [ -n "$pat2" ] && grep -Fq "$pat2" "$file"; } \
    || { [ -n "$line2" ] && grep -Fxq "$line2" "$file"; } \
    || { echo "inject_decl: unexpected upstream declaration for '$anchor' in $file" >&2; return 128; }
  printf '%s\n' "$target" > /tmp/winebuild-decl.$$
  # Replace the matching line by appending the prepared file, then deleting the
  # original. Avoid $(cat ...) inside the sed expression: it can be re-executed
  # by a POSIX shell where bash-only ${anchor//...} expansion fails.
  sed -i -e "/^${anchor//\./\\.} /r /tmp/winebuild-decl.$$" \
         -e "/^${anchor//\./\\.} /d" "$file" \
    && rm -f /tmp/winebuild-decl.$$ \
    || { rm -f /tmp/winebuild-decl.$$; echo "inject_decl: sed failed on $file" >&2; return 128; }
  [ "$(grep -cF "$anchor" "$file")" = "1" ] || { echo "inject_decl: post-check failed in $file" >&2; return 128; }
  grep -Fxq "$target" "$file" || { echo "inject_decl: target value missing in $file" >&2; return 128; }
  return 0
}

check_decl() { # file anchor expected forbidden
  local file="$1" anchor="$2" expected="$3" forbidden="$4"
  local n
  n=$(grep -cF "$anchor" "$file" || true)
  [ "$n" = "1" ] || { echo "check_decl: $n '$anchor' declarations in $file (want 1)" >&2; return 128; }
  grep -Fxq "$expected" "$file" || { echo "check_decl: expected value missing in $file:" >&2; grep -F "$anchor" "$file" >&2; return 128; }
  if [ -n "$forbidden" ] && grep -Fq "$forbidden" "$file"; then
    echo "check_decl: foreign-architecture path '$forbidden' found in $file" >&2
    return 128
  fi
  return 0
}

check_elf() { # path class machine
  local f="$1" want_class="$2" want_machine="$3"
  [ -f "$f" ] || { echo "check_elf: skip (not yet built): $f"; return 0; }
  local hdr class machine
  # readelf localizes its field labels (zh_CN prints 类别/系统架构), which would
  # defeat the English-only sed extraction below and yield a false mismatch;
  # pin LC_ALL=C so the header text is stable regardless of caller locale.
  hdr=$(LC_ALL=C readelf -h "$f" 2>/dev/null) || { echo "check_elf: readelf failed: $f" >&2; return 128; }
  class=$(printf '%s\n' "$hdr" | sed -n 's/^ *Class:[[:space:]]*//p')
  machine=$(printf '%s\n' "$hdr" | sed -n 's/^ *Machine:[[:space:]]*//p')
  [ "$class" = "$want_class" ] || { echo "check_elf: $f Class='$class' want '$want_class'" >&2; return 128; }
  case "$machine" in *"$want_machine"*) ;; *) echo "check_elf: $f Machine='$machine' want '$want_machine'" >&2; return 128;; esac
  echo "check_elf: ok $f Class=$class Machine=$machine"
  return 0
}

LOADER_IN=../loader/Makefile.in
SERVER_IN=../server/Makefile.in
WINE_OBJS_ORIG='wine_OBJS = main.o'
WINE_OBJS_NEW='wine_OBJS = main.o '"$MIMALLOC_OBJ"
WINE_OBJS32='wine_OBJS = main.o '"$MIMALLOC_OBJ32"
# The i386 stage rewrites wine_LDFLAGS/UNIX_LIBS with the same text as the x64
# stage (only wine_OBJS/UNIX_LIBS carry the object path), so that state is a
# known, accepted shape; verify it by exact line where the path is present.
UNIX_LIBS_I386='UNIX_LIBS   = '"$MIMALLOC_OBJ32"' $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'
WINE_LDFLAGS_ORIG='wine_LDFLAGS = $(WINELOADER_LDFLAGS) $(LDEXECFLAGS) $(PTHREAD_LIBS)'
WINE_LDFLAGS_NEW='wine_LDFLAGS = $(WINELOADER_LDFLAGS) $(LDEXECFLAGS) $(PTHREAD_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'
UNIX_LIBS_ORIG='UNIX_LIBS   = $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS)'
UNIX_LIBS_NEW='UNIX_LIBS   = '"$MIMALLOC_OBJ"' $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'

# Known cross-architecture states: pristine, x64-injected, i386-injected.
inject_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS_ORIG" "$WINE_OBJS_NEW" "$WINE_OBJS32" "$MIMALLOC_OBJ32" || exit 128
inject_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_ORIG" "$WINE_LDFLAGS_NEW" "" "$MIMALLOC_OBJ32" "" || exit 128
inject_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_ORIG" "$UNIX_LIBS_NEW" "" "$MIMALLOC_OBJ32" "$UNIX_LIBS_I386" || exit 128

check_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS_NEW" "$MIMALLOC_OBJ32" || exit 128
check_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_NEW" "$MIMALLOC_OBJ32" || exit 128
check_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_NEW" "$MIMALLOC_OBJ32" || exit 128

check_elf "$MIMALLOC_OBJ" "ELF64" "Advanced Micro Devices X86-64" || exit 128
check_elf "$MIMALLOC_OBJ32" "ELF32" "Intel 80386" || exit 128
check_elf loader/wine "ELF64" "Advanced Micro Devices X86-64" || exit 128
check_elf server/wineserver "ELF64" "Advanced Micro Devices X86-64" || exit 128

../configure --prefix=$P/out --enable-win64 || exit 128
make -j3 || exit 128

# After the 64-bit build, verify each target's complete link inputs in the
# generated Makefile (dependencies plus continuation-folded recipe): the x64
# object must be present in both loader/wine and server/wineserver, and no
# i386 object may appear in either block. The server object arrives via the
# UNIX_LIBS link command (never the dependency list) and rules wrap at 100
# columns, so the whole per-target block must be folded before matching.
check_rule_link_inputs() { # file target present forbidden missing-msg bad-msg
  local file="$1" target="$2" present="$3" forbidden="$4" missing="$5" bad="$6" block
  [ -f "$file" ] || { echo "$missing (no $file)" >&2; return 128; }
  block=$(awk -v t="$target:" '
    $0 ~ "^" t {on=1}
    on && /^[^ \t]/ && $0 !~ "^" t {exit}
    on {print}' "$file" \
    | awk '{line=line $0; if (sub(/\\$/, "", line)) next; print line; line=""} END {if (line != "") print line}')
  [ -n "$block" ] || { echo "$missing (no $target rule)" >&2; return 128; }
  printf '%s\n' "$block" | grep -F "$present" >/dev/null || { echo "$missing" >&2; return 128; }
  if printf '%s\n' "$block" | grep -F "$forbidden" >/dev/null; then
    echo "$bad" >&2; return 128
  fi
  return 0
}
check_rule_link_inputs Makefile loader/wine "$MIMALLOC_OBJ" "$MIMALLOC_OBJ32" \
  "loader/wine rule missing x64 mimalloc object after build" \
  "loader/wine rule references i386 mimalloc object after build" || exit 128
check_rule_link_inputs Makefile server/wineserver "$MIMALLOC_OBJ" "$MIMALLOC_OBJ32" \
  "server/wineserver rule missing x64 mimalloc object after build" \
  "server/wineserver rule references i386 mimalloc object after build" || exit 128

exit 0
