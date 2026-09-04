# I hate glibc. I hate glibc. I hate glibc. I hate glibc. I hate glibc.
# Ubuntu 18.04 = glibc 2.27. Dynamic Linux builds require glibc >= 2.27,
# which covers RHEL 8 (2.28), Ubuntu 18.04+, Debian 10+.
# Previously used deadsnakes PPA for Python 3.10 because 18.04 ships 3.6 like it's 2017.
# deadsnakes then decided 18.04 was too old to live (fair) and purged it after EOL (Apr 2023).
# So now we build Python from source like it's 1994. The circle of suffering is complete.
# If you're reading this and thinking "just upgrade to a newer base image" — see line 1.
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && \
    apt install -y software-properties-common apt-utils curl wget git \
    build-essential libssl-dev libplist-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libffi-dev libncursesw5-dev xz-utils tk-dev liblzma-dev libgdbm-dev libc6-dev libnss3-dev \
    libgc-dev cmake autoconf automake libtool libpcre2-dev

# Python 3.10 from source (deadsnakes PPA dropped bionic after 18.04 EOL)
RUN cd /tmp && \
    wget -q https://www.python.org/ftp/python/3.10.14/Python-3.10.14.tgz && \
    tar -xzf Python-3.10.14.tgz && \
    cd Python-3.10.14 && \
    ./configure --enable-optimizations --with-ensurepip=install && \
    make -j$(nproc) && make altinstall && \
    ln -sf /usr/local/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/local/bin/pip3.10 /usr/bin/pip3 && \
    rm -rf /tmp/Python-3.10.14*

RUN pip3 install pycryptodome mythic-container==0.6.16

# Crystal (direct tarball & install.sh uses apt repos that don't carry older versions on bionic)
RUN wget -q "https://github.com/crystal-lang/crystal/releases/download/1.20.1/crystal-1.20.1-1-linux-x86_64.tar.gz" -O /tmp/crystal.tar.gz && \
    tar -xzf /tmp/crystal.tar.gz -C /opt && \
    ln -sf /opt/crystal-1.20.1-1/bin/crystal /usr/local/bin/crystal && \
    ln -sf /opt/crystal-1.20.1-1/bin/shards /usr/local/bin/shards && \
    rm /tmp/crystal.tar.gz

# ldid: re-signs Mach-O ad-hoc code signatures after Zig linking on ubuntu:18.04.
# Zig on older glibc computes incorrect page hashes — ldid recomputes them correctly.
RUN git clone --depth 1 https://github.com/ProcursusTeam/ldid.git /tmp/ldid && \
    cd /tmp/ldid && make LDFLAGS="-lplist" && install -m755 ldid /usr/local/bin/ && \
    rm -rf /tmp/ldid

# rcodesign: emits SHA-256 CodeDirectory required by macOS 14+.
# ldid only produces SHA-1 hashes which macOS 26 rejects at launch.
RUN RCODESIGN_VER=$(wget -qO- "https://api.github.com/repos/indygreg/apple-platform-rs/releases/latest" | \
        grep '"tag_name"' | sed 's/.*"apple-codesign\/\([^"]*\)".*/\1/') && \
    wget -q "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F${RCODESIGN_VER}/apple-codesign-${RCODESIGN_VER}-x86_64-unknown-linux-musl.tar.gz" \
        -O /tmp/rcodesign.tar.gz && \
    tar -xzf /tmp/rcodesign.tar.gz -C /tmp && \
    install -m755 /tmp/apple-codesign-${RCODESIGN_VER}-x86_64-unknown-linux-musl/rcodesign /usr/local/bin/ && \
    rm -rf /tmp/rcodesign.tar.gz /tmp/apple-codesign-*

# OpenSSL 3.1.2 (Linux host build for Crystal compilation)
RUN cd /tmp && \
    wget https://www.openssl.org/source/openssl-3.1.2.tar.gz && \
    tar -xzf openssl-3.1.2.tar.gz && \
    cd openssl-3.1.2 && \
    ./config --prefix=/opt/openssl-3 --openssldir=/etc/ssl zlib && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/openssl-3.1.2*

# Zig (pre-built static binary — runs on any Linux kernel, glibc-independent)
RUN ZIGVER=0.13.0 && \
    wget -q "https://ziglang.org/download/${ZIGVER}/zig-linux-x86_64-${ZIGVER}.tar.xz" -O /tmp/zig.tar.xz && \
    tar -xf /tmp/zig.tar.xz -C /opt && \
    mv /opt/zig-linux-x86_64-${ZIGVER} /opt/zig && \
    ln -sf /opt/zig/zig /usr/local/bin/zig && \
    rm /tmp/zig.tar.xz

# cmake 3.28 (ubuntu:18.04 ships 3.10, pcre2 requires 3.15+)
RUN wget -q "https://github.com/Kitware/CMake/releases/download/v3.28.6/cmake-3.28.6-linux-x86_64.tar.gz" -O /tmp/cmake.tar.gz && \
    tar -xzf /tmp/cmake.tar.gz -C /opt && \
    ln -sf /opt/cmake-3.28.6-linux-x86_64/bin/cmake /usr/local/bin/cmake && \
    rm /tmp/cmake.tar.gz

# macOS 12.3 SDK
RUN mkdir -p /opt/macos-sdk && \
    wget -q "https://github.com/joseluisq/macosx-sdks/releases/download/12.3/MacOSX12.3.sdk.tar.xz" -O /tmp/macos-sdk.tar.xz && \
    tar -xf /tmp/macos-sdk.tar.xz -C /opt/macos-sdk && \
    rm /tmp/macos-sdk.tar.xz

# Build macOS static libraries via Zig cross-compiler
# Produces: libssl.a, libcrypto.a, libpcre2-8.a, libevent.a, libgc.a
# under /opt/multiarch-libs/aarch64-apple-darwin/
COPY scripts/build_macos_libs.sh /tmp/build_macos_libs.sh
RUN chmod +x /tmp/build_macos_libs.sh && \
    /tmp/build_macos_libs.sh && \
    rm /tmp/build_macos_libs.sh

RUN apt clean && rm -Rf /tmp/*

WORKDIR /Mythic/
CMD ["python3", "main.py"]
