FROM alpine:3.23
ARG TARGETARCH
ARG ZIG_VERSION=0.16.0
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) arch=x86_64;  sha=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ;; \
      arm64) arch=aarch64; sha=ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache --virtual .fetch xz; \
    tarball="zig-$arch-linux-$ZIG_VERSION.tar.xz"; \
    wget -q "https://ziglang.org/download/$ZIG_VERSION/$tarball"; \
    echo "$sha  $tarball" | sha256sum -c -; \
    mkdir /opt/zig; \
    tar -xJf "$tarball" -C /opt/zig --strip-components=1; \
    rm "$tarball"; \
    apk del .fetch; \
    ln -s /opt/zig/zig /usr/local/bin/zig
WORKDIR /app
CMD sleep infinity
