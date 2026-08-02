#!/bin/bash
set -euxo pipefail

for arg in "$@"; do
    case "$arg" in
        --rsync-version=*) VERSION="${arg#*=}" ;;
        --xxhash-version=*) XXHASH_VERSION="${arg#*=}" ;;
        --lz4-version=*) LZ4_VERSION="${arg#*=}" ;;
        --zstd-version=*) ZSTD_VERSION="${arg#*=}" ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

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
    AR=aarch64-linux-gnu-ar
    STRIP=aarch64-linux-gnu-strip
elif [ "$HOST_ARCH" = "arm64" ]; then
    apt-get install -y gcc musl-tools
    AR=ar
    STRIP=strip
else
    echo "unsupported host architecture: $HOST_ARCH" >&2
    exit 1
fi

CC="${TARGET}-gcc"
SYSROOT_INCLUDE="/usr/include/$TARGET"
SYSROOT_LIB="/usr/lib/$TARGET"

# xxhash, lz4, and zstd give rsync much faster checksumming/compression than the md5/zlib fallback,
# but Debian's dev packages for these ship glibc-ABI static libs that won't link into a static musl
# binary, so build musl versions from source and drop them into the musl sysroot instead.

curl -L -o xxhash.tar.gz "https://github.com/Cyan4973/xxHash/archive/refs/tags/v${XXHASH_VERSION}.tar.gz"
tar -xf xxhash.tar.gz
(cd "xxHash-${XXHASH_VERSION}" && CC="$CC" AR="$AR" make libxxhash.a -j"$(nproc)")
cp "xxHash-${XXHASH_VERSION}/libxxhash.a" "$SYSROOT_LIB/"
cp "xxHash-${XXHASH_VERSION}/xxhash.h" "xxHash-${XXHASH_VERSION}/xxh3.h" "$SYSROOT_INCLUDE/"

curl -L -o lz4.tar.gz "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz"
tar -xf lz4.tar.gz
(cd "lz4-${LZ4_VERSION}/lib" && CC="$CC" AR="$AR" make liblz4.a -j"$(nproc)")
cp "lz4-${LZ4_VERSION}/lib/liblz4.a" "$SYSROOT_LIB/"
cp "lz4-${LZ4_VERSION}/lib/lz4.h" "lz4-${LZ4_VERSION}/lib/lz4hc.h" "lz4-${LZ4_VERSION}/lib/lz4frame.h" "lz4-${LZ4_VERSION}/lib/lz4file.h" "$SYSROOT_INCLUDE/"

curl -L -o zstd.tar.gz "https://github.com/facebook/zstd/archive/refs/tags/v${ZSTD_VERSION}.tar.gz"
tar -xf zstd.tar.gz
(cd "zstd-${ZSTD_VERSION}/lib" && CC="$CC" AR="$AR" make libzstd.a -j"$(nproc)")
cp "zstd-${ZSTD_VERSION}/lib/libzstd.a" "$SYSROOT_LIB/"
cp "zstd-${ZSTD_VERSION}/lib/zstd.h" "zstd-${ZSTD_VERSION}/lib/zstd_errors.h" "zstd-${ZSTD_VERSION}/lib/zdict.h" "$SYSROOT_INCLUDE/"

curl -L -O "https://download.samba.org/pub/rsync/src/rsync-${VERSION}.tar.gz"
tar -xf "rsync-${VERSION}.tar.gz"
mv "rsync-${VERSION}" rsync-src

cd rsync-src
CC="$CC" ./configure --disable-openssl CFLAGS="-static" --host="$TARGET"
make -j"$(nproc)"
cd ..

mkdir -p compiled
cp -a rsync-src/rsync "compiled/rsync-${TARGET}"
cd compiled
"$STRIP" "rsync-${TARGET}"
sha256sum * > sha256sum.txt
