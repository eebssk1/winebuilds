#!/bin/bash

wget https://github.com/eebssk1/aio_tc_build/releases/latest/download/x86_64-linux-gnu-native.tb2 || exit 128
wget https://github.com/eebssk1/aio_tc_build/releases/latest/download/x86_64-w64-mingw32-cross-broadwell.tb2 || exit 128
for a in *.tb2; do
tar --bz -xf $a || exit 128
rm -rf $a
done

echo "${PWD}/x86_64-linux-gnu/bin:${PWD}/x86_64-w64-mingw32/bin:${PATH}" >> "$GITHUB_PATH"

exit 0