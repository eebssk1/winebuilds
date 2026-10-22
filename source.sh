#!/bin/bash

P=$PWD

VER="wine-11.19"
MIMALLOC_VER="v3.5.3"
MIMALLOC_SHA256="3b4a15153a59905995f7070296ed604bb5ccc00cabb8b93446931aff77224d47"
wget https://dl.winehq.org/wine/source/11.x/${VER}.tar.xz || exit 128
tar --xz -xf ${VER}.tar.xz || exit 128
rm -rf ${VER}.tar.xz

wget "https://github.com/microsoft/mimalloc/archive/refs/tags/${MIMALLOC_VER}.tar.gz" -O "mimalloc-${MIMALLOC_VER}.tar.gz" || exit 128
echo "${MIMALLOC_SHA256}  mimalloc-${MIMALLOC_VER}.tar.gz" | sha256sum -c - || exit 128
tar -xzf "mimalloc-${MIMALLOC_VER}.tar.gz" || exit 128
mv "mimalloc-${MIMALLOC_VER#v}" "mimalloc-${MIMALLOC_VER}" || exit 128
rm -f "mimalloc-${MIMALLOC_VER}.tar.gz"

git clone -b v11.19 https://github.com/wine-staging/wine-staging || exit 128
pushd wine-staging
./staging/patchinstall.py DESTDIR="$P/${VER}" --all || exit 128
popd
rm -rf wine-staging
echo "VER=${VER}" >> "$GITHUB_ENV"
exit 0


