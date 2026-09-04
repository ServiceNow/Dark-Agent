#!/bin/bash

# Color definitions for logging
log_info() {
    echo -e "\033[0;34m[*] $1\033[0m"  # Blue for info
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m"  # Red for errors
}

log_success() {
    echo -e "\033[0;32m[+] $1\033[0m"  # Green for success
}

log_action() {
    echo -e "\033[0;33m[-] $1\033[0m"  # Yellow for actions
}

# Create output directories
setup_directories() {
    mkdir -p output
    mkdir -p output/bofs
    log_info "Created output directories"
}

# Build C BOF object files
build_bofs() {
    log_info "Building BOF object files..."
    build_error=0

    # Find all .c files recursively in src/bofs directory
    find src/bofs -name "*.c" | while read c_file; do
        base_name=$(basename "$c_file")
        output_name="${base_name%.c}.o"
        log_action "Compiling $base_name from $c_file"
        gcc -fPIC -c "$c_file" -o "output/bofs/$output_name" -I src/bofs/includes -w

        if [ $? -eq 0 ]; then
            log_success "Built $output_name"
        else
            log_error "Failed to build $output_name"
            build_error=1
        fi
    done

    # Exit with error if any BOF failed to build
    if [ $build_error -eq 1 ]; then
        log_error "One or more BOFs failed to build"
        exit 1
    fi
}

# Build C BOF object files for macOS (aarch64) using Zig cross-compiler
build_bofs_macos() {
    log_info "Building BOF object files for macOS (aarch64)..."
    local MACOS_ZIG_TARGET="aarch64-linux-none"
    local MACOS_SDK="/opt/macos-sdk/MacOSX12.3.sdk"
    local build_error=0

    mkdir -p output/bofs/macos

    find src/bofs -name "*.c" | while read c_file; do
        base_name=$(basename "$c_file")
        output_name="${base_name%.c}.o"
        log_action "Compiling ${base_name} for macOS aarch64"
        /opt/zig/zig cc \
            -target "${MACOS_ZIG_TARGET}" \
            -I "${MACOS_SDK}/usr/include" \
            -D__aarch64__=1 -D__arm64__=1 \
            -DTARGET_MACOS=1 \
            -D_FORTIFY_SOURCE=0 \
            -fPIC -c "${c_file}" \
            -o "output/bofs/macos/${output_name}" \
            -I src/bofs/includes -w

        if [ $? -eq 0 ]; then
            log_success "Built ${output_name} (macOS aarch64)"
        else
            log_error "Failed to build ${output_name}"
            build_error=1
        fi
    done

    if [ $build_error -eq 1 ]; then
        log_error "One or more macOS BOFs failed to build"
        exit 1
    fi
}

# Unified build function for Dark Agent
build_agent() {
    local mode="$1"          # debug, release, or socks-debug
    local output_file="$2"   # output filename
    local extra_flags="$3"   # additional crystal build flags
    local description="$4"   # human-readable description

    log_info "Building Dark Agent in $description..."

    # Print Crystal version
    log_info "Crystal version info: "
    crystal --version

    if [ -z "$DARK_AGENT_CONFIG_PATH" ]; then
        log_error "Dark agent config JSON path not provided (DARK_AGENT_CONFIG_PATH environment variable)"
        exit 1
    fi

    log_info "Building for profile type: $PROFILE_TYPE"

    # Build base flags
    local base_flags="src/dark/dark-agent.cr"
    local profile_flags=""
    local debug_socks_flags="${DEBUG_SOCKS:+-D debug_socks}"

    # Add profile-specific flags
    if [ "$PROFILE_TYPE" = "httpx" ]; then
        profile_flags="-D httpx_profile"
    fi

    # Static OpenSSL 3 baked into the binary with no target libssl dependency.
    # --as-needed prevents pkg-config's subsequent dynamic -lssl from adding a NEEDED
    # entry once the symbols are already resolved by the static archive.
    export PKG_CONFIG_PATH="/opt/openssl-3/lib64/pkgconfig"

    # Execute crystal build with combined flags (including multi-threading support)
    echo "$base_flags $profile_flags $debug_socks_flags $extra_flags -Dpreview_mt -o $output_file"
    crystal build $base_flags $profile_flags $debug_socks_flags $extra_flags \
      --link-flags "-Wl,--as-needed -Wl,-Bstatic -L/opt/openssl-3/lib64 -lssl -lcrypto -Wl,-Bdynamic" \
      -Dpreview_mt -o "$output_file"

    if [ $? -eq 0 ]; then
        log_success "Built Dark Agent ($description) for $PROFILE_TYPE profile"
    else
        log_error "Failed to build Dark Agent in $description"
        exit 1
    fi
}

# Build Dark Agent in debug mode
build_debug() {
    build_agent "debug" "output/dark-agent-debug" "" "debug mode"
}

# Build Dark Agent in release mode
build_release() {
    build_agent "release" "output/dark-agent" "--release --no-debug" "release mode"
    strip output/dark-agent
    log_success "Stripped release binary ($(du -sh output/dark-agent | cut -f1))"
}

# Build Dark Agent in direct mode (COFF loader only)
build_direct_mode() {
    log_info "Building Dark Agent in direct mode (COFF loader only)..."

    crystal build src/dark/dark-agent-direct.cr --debug -o output/dark-agent-direct -D debugmem -Dpreview_mt

    if [ $? -eq 0 ]; then
        log_success "Built Dark Agent (direct mode)"
    else
        log_error "Failed to build Dark Agent in direct mode"
        exit 1
    fi
}

# Build standalone SOCKS server for testing
build_socks_server() {
    log_info "Building standalone SOCKS server..."

    crystal build src/socks-server.cr -o output/socks-server --release --error-trace -Dpreview_mt

    if [ $? -eq 0 ]; then
        log_success "Built standalone SOCKS server"
    else
        log_error "Failed to build SOCKS server"
        exit 1
    fi
}

# Build Dark Agent with SOCKS debugging enabled
build_socks_debug() {
    build_agent "socks-debug" "output/dark-agent-socks-debug" "-D debug -D debug_socks" "SOCKS debug mode"
}

# Build Dark Agent for macOS (Mach-O binary) via two-phase Crystal cross-compile + Zig link
build_macos() {
    local crystal_flags="$1"   # extra crystal flags (e.g. "-D debug")
    local output_file="$2"
    local description="$3"

    local MACOS_CRYSTAL_TARGET="aarch64-apple-macosx12.0"
    local MACOS_ZIG_TARGET="aarch64-macos-none"
    local MACOS_ARCH="aarch64-apple-darwin"
    local MACOS_PREFIX="/opt/multiarch-libs/${MACOS_ARCH}"
    local MACOS_SDK="/opt/macos-sdk/MacOSX12.3.sdk"
    local OBJ_FILE="${output_file}.o"

    log_info "Building Dark Agent for macOS (${description}) via cross-compile..."

    if [ -z "$DARK_AGENT_CONFIG_PATH" ]; then
        log_error "DARK_AGENT_CONFIG_PATH not set"
        exit 1
    fi

    log_info "Phase 1: Crystal → object file (target: ${MACOS_CRYSTAL_TARGET})"
    PKG_CONFIG_LIBDIR="${MACOS_PREFIX}/lib/pkgconfig" \
    crystal build \
        --cross-compile \
        --target "${MACOS_CRYSTAL_TARGET}" \
        --static \
        -Dpreview_mt \
        -Dgc_none \
        ${crystal_flags} \
        -o "${output_file}" \
        src/dark/dark-agent.cr

    if [ $? -ne 0 ]; then
        log_error "Crystal cross-compile failed"
        exit 1
    fi

    log_info "Phase 2: Zig → Mach-O binary"

    # darwin_stop_world.c requires Mach framework internals we can't cross-compile.
    # These stubs satisfy the linker. GC works cooperatively with Crystal fibers and the conservative collector tolerates the lack of explicit world-stop on macOS.
    cat > /tmp/gc_darwin_stubs.c << 'GCEOF'
void GC_push_all_stacks(void) {}
void GC_darwin_register_mach_handler_thread(void *p) { (void)p; }
void GC_start_world(void) {}
void GC_stop_world(void) {}
GCEOF
    /opt/zig/zig cc -target "${MACOS_ZIG_TARGET}" \
        -c /tmp/gc_darwin_stubs.c \
        -o output/gc_darwin_stubs.o

    /opt/zig/zig cc \
        -target "${MACOS_ZIG_TARGET}" \
        "${OBJ_FILE}" \
        output/gc_darwin_stubs.o \
        -o "${output_file}" \
        -L"${MACOS_PREFIX}/lib" \
        -L"${MACOS_SDK}/usr/lib" \
        -isysroot "${MACOS_SDK}" \
        -lssl -lcrypto \
        -lpcre2-8 \
        -lgc \
        -lz \
        -lpthread \
        -levent \
        -liconv \
        -dead_strip

    if [ $? -ne 0 ]; then
        log_error "Zig link failed"
        exit 1
    fi

    rm -f "${OBJ_FILE}"

    # Zig on ubuntu:18.04 (glibc 2.27) produces Mach-O with incorrect ad-hoc page hashes.
    # rcodesign produces SHA-256 CodeDirectory hashes required by macOS 14+; ldid only emits SHA-1.
    rcodesign sign --adhoc "${output_file}"

    log_success "Built Dark Agent (${description}) for macOS"
}

build_macos_release() {
    build_macos "--release --no-debug" "output/dark-agent-macos" "release mode"
}

build_macos_debug() {
    build_macos "-D debug" "output/dark-agent-macos-debug" "debug mode"
}


# Clean outputs
clean() {
    log_action "Cleaning output directory..."
    rm -f output/dark-agent output/dark-agent-debug output/dark-agent-direct output/dark-agent-direct.ll output/socks-server output/dark-agent-socks-debug output/dark-agent-macos output/dark-agent-macos-debug output/dark-agent-macos*.o
    rm -f output/bofs/*.o output/bofs/macos/*.o 2>/dev/null || true
    log_success "Cleaned Dark Agent builds and BOF object files"
}

# Display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -a    Build both debug and release versions"
    echo "  -b    Build BOF object files only"
    echo "  -d    Build debug version only"
    echo "  -r    Build release version only"
    echo "  -c    Clean Dark Agent builds and BOF object files"
    echo "  -D    Build direct mode version"
    echo "  -s    Build standalone SOCKS server"
    echo "  -S    Build Dark Agent with SOCKS debug mode (suppresses HTTP logs)"
    echo "  -p    Specify profile type (http or httpx)"
    echo "  -B    Build BOF object files for macOS (aarch64)"
    echo "  -m    Build macOS Mach-O binary (release)"
    echo "  -M    Build macOS Mach-O binary (debug)"
    echo "  -h    Show this help message"
}

# Default profile type is http
PROFILE_TYPE="http"

# Execute build actions based on provided arguments
execute_build() {
    local action="$1"

    case "$action" in
        "all")
            build_bofs
            build_debug
            build_release
            ;;
        "bofs")
            build_bofs
            ;;
        "bofs-macos")
            build_bofs_macos
            ;;
        "debug")
            build_debug
            ;;
        "release")
            build_release
            ;;
        "direct")
            build_direct_mode
            ;;
        "socks-server")
            build_socks_server
            ;;
        "socks-debug")
            build_socks_debug
            ;;
        "macos")
            build_macos_release
            ;;
        "macos-debug")
            build_macos_debug
            ;;
        "clean")
            clean
            return 0
            ;;
        "help")
            usage
            return 0
            ;;
    esac
}

# Main execution
if [ $# -eq 0 ]; then
    # Default to building both versions and BOFs if no args provided
    setup_directories
    execute_build "all"
    exit 0
fi

while getopts "abdrcDsShjBmMp:x:" opt; do
    case $opt in
        a) BUILD_ACTION="all" ;;
        b) BUILD_ACTION="bofs" ;;
        d) BUILD_ACTION="debug" ;;
        r) BUILD_ACTION="release" ;;
        c) BUILD_ACTION="clean" ;;
        D) BUILD_ACTION="direct" ;;
        s) BUILD_ACTION="socks-server" ;;
        S) BUILD_ACTION="socks-debug" ;;
        h) BUILD_ACTION="help" ;;
        B) BUILD_ACTION="bofs-macos" ;;
        m) BUILD_ACTION="macos" ;;
        M) BUILD_ACTION="macos-debug" ;;
        p)
            PROFILE_TYPE="$OPTARG"
            if [ "$PROFILE_TYPE" != "http" ] && [ "$PROFILE_TYPE" != "httpx" ]; then
                log_error "Invalid profile type: $PROFILE_TYPE. Must be 'http' or 'httpx'"
                exit 1
            fi
            log_info "Using profile type: $PROFILE_TYPE"
            ;;
        x)
            DEBUG_SOCKS=1
            log_info "SOCKS debug mode enabled"
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

# Execute the build action if one was specified
if [ -n "$BUILD_ACTION" ]; then
    # Only setup directories if we're not just cleaning or showing help
    if [ "$BUILD_ACTION" != "clean" ] && [ "$BUILD_ACTION" != "help" ]; then
        setup_directories
    fi
    execute_build "$BUILD_ACTION"
fi

exit 0
