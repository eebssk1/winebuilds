#!/bin/bash

P=$PWD

cd $VER
mkdir b64
cd b64

DEP="libasound2-dev libpulse-dev libdbus-1-dev libfontconfig-dev libfreetype-dev libgnutls28-dev libssl-dev libgl-dev libunwind-dev libx11-dev libxcomposite-dev libxcursor-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev libxext-dev libwayland-bin libwayland-dev libegl-dev libwayland-dev libxkbcommon-dev libxkbregistry-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libosmesa6-dev libsdl2-dev libudev-dev libvulkan-dev libcups2-dev samba-dev ocl-icd-opencl-dev libusb-1.0-0-dev libv4l-dev"

apt install --ignore-missing -y $DEP || exit 128

export CFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export CXXFLAGS="-O3 -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ -flimit-function-alignment -falign-loops=32:16:16:11"
export x86_64_CFLAGS="$CFLAGS"
export i386_CFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O3 -static-libgcc -static-libstdc++"
export LDEXECFLAGS="$LDFLAGS"

../configure --prefix=$P/out --enable-win64 || exit 128
make -j3 || exit 128

exit 0