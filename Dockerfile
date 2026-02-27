FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    live-build \
    p7zip-full \
    xorriso \
    isolinux \
    syslinux-common \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY scripts/build_iso.sh /usr/local/bin/build_iso.sh
RUN chmod +x /usr/local/bin/build_iso.sh

ENTRYPOINT ["/usr/local/bin/build_iso.sh"]
