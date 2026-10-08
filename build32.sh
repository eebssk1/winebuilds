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

../configure --prefix=$P/out --with-wine64=$PWD/../b64 || exit 128
make -j3 || exit 128
make install-strip || make install || exit 128
popd
pushd b64
make install-strip || make install || exit 128

exit 0