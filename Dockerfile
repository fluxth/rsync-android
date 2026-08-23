FROM debian:sid-20260713@sha256:7469781d68f44940c9494eeba6e7ab89063947f794320d61c193bf027aeb7761

# renovate: datasource=github-releases depName=RsyncProject/rsync extractVersion=^v(?<version>.*)$
ARG RSYNC_VERSION=3.5.0
# renovate: datasource=github-releases depName=Cyan4973/xxHash extractVersion=^v(?<version>.*)$
ARG XXHASH_VERSION=0.8.3
# renovate: datasource=github-releases depName=lz4/lz4 extractVersion=^v(?<version>.*)$
ARG LZ4_VERSION=1.10.0
# renovate: datasource=github-releases depName=facebook/zstd extractVersion=^v(?<version>.*)$
ARG ZSTD_VERSION=1.5.7

WORKDIR /build
COPY scripts/build-rsync-android.sh .
RUN ./build-rsync-android.sh --rsync-version="$RSYNC_VERSION" --xxhash-version="$XXHASH_VERSION" --lz4-version="$LZ4_VERSION" --zstd-version="$ZSTD_VERSION"
