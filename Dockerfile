FROM debian:sid@sha256:7469781d68f44940c9494eeba6e7ab89063947f794320d61c193bf027aeb7761

# renovate: datasource=github-releases depName=RsyncProject/rsync extractVersion=^v(?<version>.*)$
ARG RSYNC_VERSION=3.4.4

WORKDIR /build
COPY scripts/build-rsync-android.sh .
RUN ./build-rsync-android.sh "$RSYNC_VERSION"
