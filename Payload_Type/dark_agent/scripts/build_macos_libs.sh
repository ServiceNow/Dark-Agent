#!/bin/bash
# Builds macOS static libraries from source using Zig as the cross-compiler.
# Runs once at Docker image build time. Produces libs under /opt/multiarch-libs/aarch64-apple-darwin/.
#
# Requires:
#   - zig in PATH
#   - macOS SDK at /opt/macos-sdk/MacOSX12.3.sdk
#   - cmake, wget, tar, make in PATH

set -e

MACOS_TARGET="aarch64-macos-none"
MACOS_SDK="/opt/macos-sdk/MacOSX12.3.sdk"
MACOS_PREFIX="/opt/multiarch-libs/aarch64-apple-darwin"
JOBS=2

ZIG_CC="zig cc -target ${MACOS_TARGET} -isysroot ${MACOS_SDK}"
ZIG_CXX="zig c++ -target ${MACOS_TARGET} -isysroot ${MACOS_SDK}"
ZIG_AR="zig ar"
ZIG_RANLIB="zig ranlib"

mkdir -p "${MACOS_PREFIX}/lib/pkgconfig"
mkdir -p "${MACOS_PREFIX}/include"
mkdir -p /tmp/macos-libs-build
cd /tmp/macos-libs-build

# cmake needs single-binary tools so create wrappers since zig uses subcommands
# and cmake doesn't reliably propagate CMAKE_C_FLAGS to all compilation steps
cat > /tmp/zig-ar << 'ZIGEOF'
#!/bin/sh
zig ar "$@"
ZIGEOF
chmod +x /tmp/zig-ar

cat > /tmp/zig-ranlib << 'ZIGEOF'
#!/bin/sh
zig ranlib "$@"
ZIGEOF
chmod +x /tmp/zig-ranlib

# zig-cc wrapper: bakes in the macOS cross-compile target + sysroot so cmake
# always gets the right flags regardless of how it invokes the compiler
cat > /tmp/zig-cc << ZIGEOF
#!/bin/sh
zig cc -target ${MACOS_TARGET} -isysroot ${MACOS_SDK} "\$@"
ZIGEOF
chmod +x /tmp/zig-cc

echo "[*] Building OpenSSL for macOS..."
OPENSSL_VER=3.1.2
wget -q "https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz"
tar -xzf "openssl-${OPENSSL_VER}.tar.gz"
cd "openssl-${OPENSSL_VER}"
# -DOPENSSL_NO_APPLE_CRYPTO_RANDOM: skip CommonCrypto hardware RNG (requires macOS headers we don't have at cross-compile time)
CC="zig cc" \
CFLAGS="-target ${MACOS_TARGET} -isysroot ${MACOS_SDK} -DOPENSSL_NO_APPLE_CRYPTO_RANDOM" \
AR="${ZIG_AR}" \
RANLIB="${ZIG_RANLIB}" \
./Configure darwin64-arm64 \
    no-shared \
    no-tests \
    no-ui-console \
    no-async \
    --prefix="${MACOS_PREFIX}" \
    --openssldir="/etc/ssl"
make -j${JOBS} build_libs
make install_dev
cd /tmp/macos-libs-build
echo "[+] OpenSSL done"

echo "[*] Building pcre2 for macOS..."
PCRE2_VER=10.47
wget -q "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VER}/pcre2-${PCRE2_VER}.tar.gz"
tar -xzf "pcre2-${PCRE2_VER}.tar.gz"
mkdir -p "pcre2-${PCRE2_VER}/build" && cd "pcre2-${PCRE2_VER}/build"
cmake .. \
    -DBUILD_SHARED_LIBS=OFF \
    -DPCRE2_BUILD_TESTS=OFF \
    -DPCRE2_BUILD_PCRE2GREP=OFF \
    -DCMAKE_C_COMPILER="/tmp/zig-cc" \
    -DCMAKE_AR="/tmp/zig-ar" \
    -DCMAKE_RANLIB="/tmp/zig-ranlib" \
    -DCMAKE_INSTALL_PREFIX="${MACOS_PREFIX}" \
    -DCMAKE_SYSTEM_NAME=Darwin
make -j${JOBS}
make install
cd /tmp/macos-libs-build
echo "[+] pcre2 done"

echo "[*] Building libevent for macOS..."
LIBEVENT_VER=2.1.12
wget -q "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER}-stable/libevent-${LIBEVENT_VER}-stable.tar.gz"
tar -xzf "libevent-${LIBEVENT_VER}-stable.tar.gz"
cd "libevent-${LIBEVENT_VER}-stable"
CC="${ZIG_CC}" \
CXX="${ZIG_CXX}" \
AR="/tmp/zig-ar" \
RANLIB="/tmp/zig-ranlib" \
./configure \
    --host=aarch64-apple-darwin \
    --disable-shared \
    --enable-static \
    --disable-openssl \
    --disable-samples \
    --disable-libevent-regress \
    --prefix="${MACOS_PREFIX}"
make -j${JOBS}
make install
cd /tmp/macos-libs-build
echo "[+] libevent done"

# Stub out missing SDK headers that bdw-gc needs for macOS targets.
# The joseluisq MacOSX12.3.sdk omits some deprecated Mach headers.
# These stubs satisfy the #include without pulling in real implementations
# bdw-gc's actual Darwin code paths are disabled via cmake flags below.
mkdir -p "${MACOS_SDK}/usr/include/mach-o"
cat > "${MACOS_SDK}/usr/include/mach-o/getsect.h" << 'STUBEOF'
#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
struct mach_header_64;
static inline uint8_t *getsectiondata(const struct mach_header_64 *mhp,
    const char *seg, const char *sect, unsigned long *sz) { (void)mhp; (void)seg; (void)sect; *sz=0; return 0; }
extern uint8_t *get_etext(void);
extern uint8_t *get_end(void);
extern uint8_t *get_edata(void);
#ifdef __cplusplus
}
#endif
STUBEOF

mkdir -p "${MACOS_SDK}/usr/include/mach"
# Provide mach/exception.h so bdw-gc's darwin_stop_world.c can compile.
# This gives the GC real GC_push_all_stacks/GC_start_world/GC_stop_world
# implementations that properly handle multi-threaded Crystal (preview_mt).
[ -f "${MACOS_SDK}/usr/include/mach/exception.h" ] || \
cat > "${MACOS_SDK}/usr/include/mach/exception.h" << 'STUBEOF'
#pragma once
#ifndef _MACH_EXCEPTION_H_
#define _MACH_EXCEPTION_H_

#include <mach/port.h>
#include <mach/message.h>

typedef int                    exception_type_t;
typedef int                    exception_data_type_t;
typedef exception_data_type_t *exception_data_t;
typedef unsigned int           exception_mask_t;
typedef exception_mask_t      *exception_mask_array_t;
typedef int                    exception_behavior_t;
typedef exception_behavior_t  *exception_behavior_array_t;
typedef mach_port_t           *exception_port_array_t;

#define EXC_BAD_ACCESS           1
#define EXC_ARITHMETIC           2
#define EXC_EMULATION            3
#define EXC_SOFTWARE             4
#define EXC_BREAKPOINT           5
#define EXC_SYSCALL              6
#define EXC_MACH_SYSCALL         7
#define EXC_RPC_ALERT            8
#define EXC_CRASH               10
#define EXC_RESOURCE            11
#define EXC_GUARD               12
#define EXC_CORPSE_NOTIFY       13

#define EXC_MASK_BAD_ACCESS      (1 << EXC_BAD_ACCESS)
#define EXC_MASK_ARITHMETIC      (1 << EXC_ARITHMETIC)
#define EXC_MASK_EMULATION       (1 << EXC_EMULATION)
#define EXC_MASK_SOFTWARE        (1 << EXC_SOFTWARE)
#define EXC_MASK_BREAKPOINT      (1 << EXC_BREAKPOINT)
#define EXC_MASK_SYSCALL         (1 << EXC_SYSCALL)
#define EXC_MASK_MACH_SYSCALL    (1 << EXC_MACH_SYSCALL)
#define EXC_MASK_RPC_ALERT       (1 << EXC_RPC_ALERT)
#define EXC_MASK_CRASH           (1 << EXC_CRASH)
#define EXC_MASK_RESOURCE        (1 << EXC_RESOURCE)
#define EXC_MASK_GUARD           (1 << EXC_GUARD)
#define EXC_MASK_CORPSE_NOTIFY   (1 << EXC_CORPSE_NOTIFY)
#define EXC_MASK_ALL             (EXC_MASK_BAD_ACCESS | EXC_MASK_ARITHMETIC | \
                                  EXC_MASK_EMULATION  | EXC_MASK_SOFTWARE   | \
                                  EXC_MASK_BREAKPOINT | EXC_MASK_SYSCALL    | \
                                  EXC_MASK_MACH_SYSCALL)

#define EXCEPTION_DEFAULT            1
#define EXCEPTION_STATE              2
#define EXCEPTION_STATE_IDENTITY     3
#define MACH_EXCEPTION_CODES         0x80000000

#endif /* _MACH_EXCEPTION_H_ */
STUBEOF

echo "[*] Building Boehm GC for macOS..."
BDWGC_VER=8.2.12
ATOMICOPS_VER=7.10.0
wget -q "https://github.com/ivmai/bdwgc/releases/download/v${BDWGC_VER}/gc-${BDWGC_VER}.tar.gz"
wget -q "https://github.com/ivmai/libatomic_ops/releases/download/v${ATOMICOPS_VER}/libatomic_ops-${ATOMICOPS_VER}.tar.gz"
tar -xzf "gc-${BDWGC_VER}.tar.gz"
tar -xzf "libatomic_ops-${ATOMICOPS_VER}.tar.gz"
mv "libatomic_ops-${ATOMICOPS_VER}" "gc-${BDWGC_VER}/libatomic_ops"
mkdir -p "gc-${BDWGC_VER}/build" && cd "gc-${BDWGC_VER}/build"
cmake .. \
    -DBUILD_SHARED_LIBS=OFF \
    -Dbuild_tests=OFF \
    -Denable_docs=OFF \
    -Denable_dynamic_loading=OFF \
    -DCMAKE_C_COMPILER="/tmp/zig-cc" \
    -DCMAKE_C_FLAGS="-I${MACOS_SDK}/usr/include" \
    -DCMAKE_AR="/tmp/zig-ar" \
    -DCMAKE_RANLIB="/tmp/zig-ranlib" \
    -DCMAKE_INSTALL_PREFIX="${MACOS_PREFIX}"
make -j${JOBS}
make install
cd /tmp/macos-libs-build
echo "[+] Boehm GC done"

echo "[*] Building zlib for macOS..."
ZLIB_VER=1.3.1
wget -q "https://github.com/madler/zlib/releases/download/v${ZLIB_VER}/zlib-${ZLIB_VER}.tar.gz"
tar -xzf "zlib-${ZLIB_VER}.tar.gz"
cd "zlib-${ZLIB_VER}"
CC="/tmp/zig-cc" \
AR="/tmp/zig-ar" \
RANLIB="/tmp/zig-ranlib" \
./configure \
    --static \
    --prefix="${MACOS_PREFIX}"
make -j${JOBS} libz.a
make install
cd /tmp/macos-libs-build
echo "[+] zlib done"

rm -rf /tmp/macos-libs-build
echo "[+] All macOS static libraries built successfully"
echo "    Installed to: ${MACOS_PREFIX}"
ls "${MACOS_PREFIX}/lib/"*.a
