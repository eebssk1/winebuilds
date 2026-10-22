#!/bin/bash

P=$PWD

cd $VER
mkdir b32
pushd b32

DEP="libasound2-dev:i386 libpulse-dev:i386 libdbus-1-dev:i386 libfontconfig-dev:i386 libfreetype-dev:i386 libgnutls28-dev:i386 libssl-dev:i386 libgl-dev:i386 libunwind-dev:i386 libx11-dev:i386 libxcomposite-dev:i386 libxcursor-dev:i386 libxfixes-dev:i386 libxi-dev:i386 libxrandr-dev:i386 libxrender-dev:i386 libxext-dev:i386 libwayland-bin:i386 libwayland-dev:i386 libegl-dev:i386 libwayland-dev:i386 libxkbcommon-dev:i386 libxkbregistry-dev:i386 libgstreamer1.0-dev:i386 libgstreamer-plugins-base1.0-dev:i386 libosmesa6-dev:i386 libsdl2-dev:i386 libudev-dev:i386 libvulkan-dev:i386 libcups2-dev:i386 samba-dev:i386 ocl-icd-opencl-dev:i386 libusb-1.0-0-dev:i386 libv4l-dev:i386"

apt install --ignore-missing -y $DEP || exit 128

export CFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export CXXFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export x86_64_CFLAGS="$CFLAGS"
export i386_CFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O3 -static-libgcc -static-libstdc++"
export LDEXECFLAGS="$LDFLAGS"

MIMALLOC_SRC="$P/mimalloc-v3.5.3"
cmake -S "$MIMALLOC_SRC" -B b32/mimalloc \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_C_FLAGS=-m32 \
  -DMI_OVERRIDE=ON -DMI_BUILD_STATIC=ON -DMI_BUILD_OBJECT=ON \
  -DMI_BUILD_SHARED=OFF -DMI_BUILD_TESTS=OFF \
  -DMI_OPT_ARCH=OFF -DMI_STATS=OFF -DMI_PROFILE=OFF \
  -DMI_TLS_MODEL=LOCAL_DYNAMIC || exit 128
cmake --build b32/mimalloc --target mimalloc-obj-target || exit 128
MIMALLOC_OBJ="$PWD/b32/mimalloc/mimalloc.o"
# After `cd $VER` at the top of this script, PWD is $VER/b32 here; the 64-bit
# sibling built by build64.sh is one level up, then b64/b64/mimalloc/mimalloc.o.
MIMALLOC_OBJ64="$(dirname "$PWD")/b64/b64/mimalloc/mimalloc.o"

# Idempotent injection into a controlled declaration line of a shared
# Makefile.in template. Restores the target value from the original, x64,
# or i386 state; aborts (128) on a missing/duplicated declaration or an
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
WINE_OBJS64='wine_OBJS = main.o '"$MIMALLOC_OBJ64"
# i386 state left by this script; captured after the i386 value exists so the
# restore step has a real known pre-restore state (an earlier alias here would
# read undefined variables and stay empty).
WINE_OBJS_CUR=""
# The x64 stage rewrites wine_LDFLAGS/UNIX_LIBS with the same text as the i386
# stage (only wine_OBJS/UNIX_LIBS carry the object path), so that state is a
# known, accepted shape; verify it by exact line where the path is present.
UNIX_LIBS_X64='UNIX_LIBS   = '"$MIMALLOC_OBJ64"' $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'
UNIX_LIBS_CUR=""
WINE_LDFLAGS_ORIG='wine_LDFLAGS = $(WINELOADER_LDFLAGS) $(LDEXECFLAGS) $(PTHREAD_LIBS)'
WINE_LDFLAGS_NEW='wine_LDFLAGS = $(WINELOADER_LDFLAGS) $(LDEXECFLAGS) $(PTHREAD_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'
UNIX_LIBS_ORIG='UNIX_LIBS   = $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS)'
UNIX_LIBS_NEW='UNIX_LIBS   = '"$MIMALLOC_OBJ"' $(LDEXECFLAGS) $(RT_LIBS) $(INOTIFY_LIBS) $(PROCSTAT_LIBS) -Wl,--export-dynamic -lpthread -lrt -latomic'

# Known cross-architecture states: pristine, x64-injected, i386-injected.
inject_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS_ORIG" "$WINE_OBJS_NEW" "$WINE_OBJS64" "$MIMALLOC_OBJ64" || exit 128
inject_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_ORIG" "$WINE_LDFLAGS_NEW" "" "$MIMALLOC_OBJ64" "" || exit 128
inject_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_ORIG" "$UNIX_LIBS_NEW" "" "$MIMALLOC_OBJ64" "$UNIX_LIBS_X64" || exit 128

check_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS_NEW" "$MIMALLOC_OBJ64" || exit 128
check_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_NEW" "$MIMALLOC_OBJ64" || exit 128
check_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_NEW" "$MIMALLOC_OBJ64" || exit 128
# The templates now hold this script's i386 state; remember those exact lines
# for the later x64 restore (the initial aliases above captured nothing).
WINE_OBJS_CUR="$WINE_OBJS_NEW"
UNIX_LIBS_CUR="$UNIX_LIBS_NEW"

check_elf "$MIMALLOC_OBJ" "ELF32" "Intel 80386" || exit 128
check_elf "$MIMALLOC_OBJ64" "ELF64" "Advanced Micro Devices X86-64" || exit 128
check_elf loader/wine "ELF32" "Intel 80386" || exit 128
check_elf server/wineserver "ELF32" "Intel 80386" || exit 128

../configure --prefix=$P/out --with-wine64=$PWD/../b64 || exit 128
make -j3 || exit 128
make install-strip || make install || exit 128
popd
pushd b64

# Restore both shared templates to the x64 declarations before touching the
# 64-bit build tree again, so rule regeneration can never pick up i386 paths.
# Known states here: pristine, x64-injected, i386-injected (left by this script).
# Write the explicit x64 declarations ($WINE_OBJS64/$UNIX_LIBS_X64) — never the
# i386 text this script just left — so the following check can require the x64
# object while forbidding the i386 one. The i386 lines saved above are passed
# only as the accepted pre-restore state.
inject_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS_ORIG" "$WINE_OBJS64" "$WINE_OBJS_CUR" "$MIMALLOC_OBJ64" || exit 128
inject_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_ORIG" "$WINE_LDFLAGS_NEW" "" "$MIMALLOC_OBJ64" "" || exit 128
inject_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_ORIG" "$UNIX_LIBS_X64" "" "$MIMALLOC_OBJ64" "$UNIX_LIBS_CUR" || exit 128

check_decl "$LOADER_IN" 'wine_OBJS =' "$WINE_OBJS64" "$MIMALLOC_OBJ" || exit 128
check_decl "$LOADER_IN" 'wine_LDFLAGS =' "$WINE_LDFLAGS_NEW" "$MIMALLOC_OBJ" || exit 128
check_decl "$SERVER_IN" 'UNIX_LIBS   =' "$UNIX_LIBS_X64" "$MIMALLOC_OBJ" || exit 128

# Regenerate loader/server build rules from the restored x64 templates
# (targeted makedep run, not a full rebuild).
make depend || exit 128

# Verify each regenerated target's complete link inputs (dependencies plus
# continuation-folded recipe): the x64 object in both blocks, the i386 object
# in neither. The server object arrives via the UNIX_LIBS link command only,
# and rules wrap at 100 columns, so folding the whole per-target block is
# required before matching.
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
check_rule_link_inputs Makefile loader/wine "$MIMALLOC_OBJ64" "$MIMALLOC_OBJ" \
  "loader/wine rule missing x64 mimalloc object after regeneration" \
  "loader/wine rule references i386 mimalloc object after regeneration" || exit 128
check_rule_link_inputs Makefile server/wineserver "$MIMALLOC_OBJ64" "$MIMALLOC_OBJ" \
  "server/wineserver rule missing x64 mimalloc object after regeneration" \
  "server/wineserver rule references i386 mimalloc object after regeneration" || exit 128

check_elf "$MIMALLOC_OBJ64" "ELF64" "Advanced Micro Devices X86-64" || exit 128
check_elf loader/wine "ELF64" "Advanced Micro Devices X86-64" || exit 128
check_elf server/wineserver "ELF64" "Advanced Micro Devices X86-64" || exit 128

make install-strip || make install || exit 128

exit 0
