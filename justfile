INSTALL_PREFIX := `realpath ../sail-riscv-tests-install`

ARCH := shell('arch')
OS := shell('uname')

# NOTE: Not every release of this toolchain comes with the vector extension enabled.
# This must be manually verified for each release.
TOOLCHAIN_RELEASE_DATE := "2026.03.13"
SPIKE_COMMIT_HASH := "f51df5d3955a27602a872eaf01492177513baf6f"
SAIL_RISCV_RELEASE := "0.10"

TOOLCHAIN_URL := "https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/" + TOOLCHAIN_RELEASE_DATE + "/riscv64-elf-ubuntu-22.04-gcc.tar.xz"
SAIL_RISCV_DOWNLOAD_URL := "https://github.com/riscv/sail-riscv/releases/download/" + SAIL_RISCV_RELEASE + "/sail-riscv-" + OS + "-" + ARCH + ".tar.gz"

RISCV_TESTS_ARCHIVE := "riscv-tests.tar.gz"
VECTOR_TESTS_ARCHIVE_PREFIX := "riscv-vector-tests-"
ARCH_TESTS_ARCHIVE := "riscv-arch-tests.tar.gz"
RELEASE_DOWNLOAD_URL := "https://github.com/riscv-software-src/sail-riscv-tests/releases/download"

default:
    @just --unstable --list

### Version recipes

show-spike-hash:
    @echo {{SPIKE_COMMIT_HASH}}

show-toolchain-release:
    @echo {{TOOLCHAIN_RELEASE_DATE}}

show-sail-riscv-release:
    @echo {{SAIL_RISCV_RELEASE}}

### Toolchain recipe

install-toolchain prefix=INSTALL_PREFIX:
    wget -O- -q {{TOOLCHAIN_URL}} | tar -C {{prefix}} -xJf -
    # Save some space
    rm -rf {{prefix}}/riscv/share/info {{prefix}}/riscv/share/man

### riscv-tests recipes

# The below recipes require the toolchain installed above to be in the
# path.  `just` version 1.47.0 and later allows setting environment
# variables using the `[env(ENV_VAR, VALUE)]` attribute, but this version
# is too new to assume as installed.  Instead, we rely on the path to be
# set externally for now (see run.sh).

[working-directory: 'riscv-tests']
prepare-riscv-tests prefix=INSTALL_PREFIX:
    git submodule update --init --recursive
    autoconf
    ./configure --prefix={{prefix}}/riscv-tests

[working-directory: 'riscv-tests']
build-riscv-tests prefix=INSTALL_PREFIX: (prepare-riscv-tests prefix)
    make isa XLEN=32
    make isa XLEN=64
    make install

[working-directory: 'riscv-tests']
riscv-tests-tgz prefix=INSTALL_PREFIX: (build-riscv-tests prefix)
    tar -cvzf ../{{RISCV_TESTS_ARCHIVE}} --exclude='*.dump' --exclude ".gitignore" --exclude "Makefile" -C {{prefix}}/riscv-tests/share/riscv-tests/isa .

[working-directory: 'riscv-tests']
clean-riscv-tests:
    make clean

### Spike recipes

[script("/usr/bin/bash")]
prepare-spike:
    set -euxo pipefail
    if [ ! -d riscv-isa-sim ]; then
      git clone https://github.com/riscv-software-src/riscv-isa-sim.git
      mkdir riscv-isa-sim/build
    fi
    git -C riscv-isa-sim reset --hard {{SPIKE_COMMIT_HASH}}

[working-directory: 'riscv-isa-sim/build']
build-spike prefix=INSTALL_PREFIX: prepare-spike
    ../configure --prefix={{prefix}}/riscv --without-boost --without-boost-asio --without-boost-regex
    make -j$(nproc)
    make install

[working-directory: 'riscv-isa-sim/build']
clean-spike:
    make clean

### riscv-vector-tests recipes

[working-directory: 'riscv-vector-tests']
prepare-vector-tests prefix=INSTALL_PREFIX:
    git submodule update --init --recursive

# The two stage make below is due to a bug in the upstream Makefile; this is the approach they use in their CI.
[doc]
[working-directory: 'riscv-vector-tests']
build-vector-tests VLEN XLEN prefix=INSTALL_PREFIX: (prepare-vector-tests prefix)
    make generate-stage1 --environment-overrides VLEN={{VLEN}} XLEN={{XLEN}}
    make all -j$(nproc)  --environment-overrides VLEN={{VLEN}} XLEN={{XLEN}}

[working-directory: 'riscv-vector-tests']
vector-tests-tgz VLEN XLEN prefix=INSTALL_PREFIX: (build-vector-tests VLEN XLEN prefix)
    tar -czf ../{{VECTOR_TESTS_ARCHIVE_PREFIX}}v{{VLEN}}x{{XLEN}}.tar.gz --transform='s,^./,rv{{XLEN}},' --verbose --show-transformed-names -C out/v{{VLEN}}x{{XLEN}}machine/bin/stage2 .

[working-directory: 'riscv-vector-tests']
clean-vector-tests:
    make clean

### ACT4 riscv-arch-tests recipes

# ACT4 has other dependencies (e.g. `mise`) ; this script does not handle those.

install-sail-riscv prefix=INSTALL_PREFIX:
    mkdir -p {{prefix}}/sail-riscv
    wget -O- -q {{SAIL_RISCV_DOWNLOAD_URL}} | tar -C {{prefix}}/sail-riscv -xzf - --strip-components=1

[working-directory: 'riscv-arch-test']
prepare-arch-tests prefix=INSTALL_PREFIX:
    git submodule update --init --recursive
    mise trust .mise.toml

# The below recipes for ACT4 require the Sail RISC-V simulator in the path.  See above
# comment about setting environment variables.

[working-directory: 'riscv-arch-test']
build-arch-tests prefix=INSTALL_PREFIX: (prepare-arch-tests prefix)
    CONFIG_FILES="config/sail/sail-rv64-max/test_config.yaml config/sail/sail-rv32-max/test_config.yaml" FAST=True make elfs --jobs $(nproc)

[working-directory: 'riscv-arch-test']
arch-tests-tgz prefix=INSTALL_PREFIX: (build-arch-tests prefix)
    tar -cvzf ../{{ARCH_TESTS_ARCHIVE}} --exclude='*.objdump' --dereference -C work sail-rv32-max/elfs sail-rv64-max/elfs

[working-directory: 'riscv-arch-test']
clean-arch-tests:
    make clean

### Release management

[script("/usr/bin/bash")]
download-release release:
    set -eux
    mkdir -p releases/{{release}}
    if [ ! -f releases/{{release}}/{{RISCV_TESTS_ARCHIVE}} ]; then
      wget -O releases/{{release}}/{{RISCV_TESTS_ARCHIVE}} {{RELEASE_DOWNLOAD_URL}}/{{release}}/{{RISCV_TESTS_ARCHIVE}}
    fi
    for vlen in 128 256 512; do
      for xlen in 32 64; do
        if [ ! -f releases/{{release}}/{{VECTOR_TESTS_ARCHIVE_PREFIX}}v${vlen}x${xlen}.tar.gz ]; then
          wget -O releases/{{release}}/{{VECTOR_TESTS_ARCHIVE_PREFIX}}v${vlen}x${xlen}.tar.gz {{RELEASE_DOWNLOAD_URL}}/{{release}}/{{VECTOR_TESTS_ARCHIVE_PREFIX}}v${vlen}x${xlen}.tar.gz
        fi
      done
    done

# This provides only a summary. For detailed differences, run `compare-releases.py` directly with `-v`.
[doc]
compare-releases previous current: (download-release previous) (download-release current)
    ./compare-releases.py -p releases/{{previous}} -c releases/{{current}}

### Miscellaneous

show-default-install-prefix:
    @echo {{INSTALL_PREFIX}}

clean: clean-riscv-tests clean-vector-tests clean-spike clean-arch-tests
