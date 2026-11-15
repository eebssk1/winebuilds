#!/bin/bash

P=$PWD

BASE_VER="11.22"

VER="wine-$BASE_VER"
MIMALLOC_VER="v3.6.1"
MIMALLOC_SHA256="7321fbe8e3d2bb447cba127603c44450db0d8ef35e8240bb4a56a7455eba0a68"
wget https://dl.winehq.org/wine/source/11.x/${VER}.tar.xz || exit 128
tar --xz -xf ${VER}.tar.xz || exit 128
rm -rf ${VER}.tar.xz

wget "https://github.com/microsoft/mimalloc/releases/download/${MIMALLOC_VER}/mimalloc-${MIMALLOC_VER}-source.tar.gz" -O "mimalloc-${MIMALLOC_VER}.tar.gz" || exit 128
echo "${MIMALLOC_SHA256}  mimalloc-${MIMALLOC_VER}.tar.gz" | sha256sum -c - || exit 128
tar -xzf "mimalloc-${MIMALLOC_VER}.tar.gz" || exit 128
rm -f "mimalloc-${MIMALLOC_VER}.tar.gz"
mv mimalloc-* "mimalloc-${MIMALLOC_VER}" || exit 128

git clone -b v$BASE_VER https://github.com/wine-staging/wine-staging || exit 128
pushd wine-staging
./staging/patchinstall.py DESTDIR="$P/${VER}" --all || exit 128
popd
rm -rf wine-staging
echo "VER=${VER}" >> "$GITHUB_ENV"
exit 0


