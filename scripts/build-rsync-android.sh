#!/bin/bash
set -euxo pipefail

VERSION="$1"
TARGET=aarch64-linux-musl
HOST_ARCH=$(dpkg --print-architecture)

apt-get update
apt-get install -y curl make

# Target is always aarch64-linux-musl (Android). On an amd64 host that's a cross-compile via the
# foreign-arch packages, on an arm64 host, host arch equals target arch, so it's a native musl build
# instead.
if [ "$HOST_ARCH" = "amd64" ]; then
    dpkg --add-architecture arm64
    apt-get update
    apt-get install -y gcc-aarch64-linux-gnu musl-tools:arm64
    STRIP=aarch64-linux-gnu-strip
elif [ "$HOST_ARCH" = "arm64" ]; then
    apt-get install -y gcc musl-tools
    STRIP=strip
else
    echo "unsupported host architecture: $HOST_ARCH" >&2
    exit 1
fi

curl -L -O "https://download.samba.org/pub/rsync/src/rsync-${VERSION}.tar.gz"
tar -xf "rsync-${VERSION}.tar.gz"
mv "rsync-${VERSION}" rsync-src

cd rsync-src
CC="${TARGET}-gcc" ./configure --disable-openssl --disable-xxhash --disable-zstd --disable-lz4 CFLAGS="-static" --host="$TARGET"
make -j"$(nproc)"
cd ..

mkdir -p compiled
cp -a rsync-src/rsync "compiled/rsync-${TARGET}"
cd compiled
"$STRIP" "rsync-${TARGET}"
sha256sum * > sha256sum.txt
