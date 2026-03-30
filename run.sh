#!/usr/bin/bash
set -euxo pipefail

# This script just runs the whole build workflow locally.

INSTALL_PREFIX=`realpath ../sail-riscv-tests-install`
# The `just` package on Ubuntu 24.04 doesn't support the script attribute.
JUST="just --unstable"

# Install the toolchain.
${JUST} install-toolchain ${INSTALL_PREFIX}

# Make it available.
# The `just` package on Ubuntu 24.04 doesn't support the env attribute.
export PATH=${INSTALL_PREFIX}/riscv/bin:${PATH}

# riscv-tests
${JUST} riscv-tests-tgz ${INSTALL_PREFIX}
#${JUST} cleanup-riscv-tests ${INSTALL_PREFIX}

# Set up Spike install.
# The `just` package on Ubuntu 24.04 doesn't support the env attribute.
export RISCV=${INSTALL_PREFIX}/riscv

# Spike
${JUST} build-spike ${INSTALL_PREFIX}
#${JUST} clean-spike

# riscv-vector-tests
${JUST} vector-tests-tgz 128 32
${JUST} vector-tests-tgz 128 64
${JUST} vector-tests-tgz 256 32
${JUST} vector-tests-tgz 256 64
${JUST} vector-tests-tgz 512 32
${JUST} vector-tests-tgz 512 64
#${JUST} clean-vector-tests

# Sail RISC-V
${JUST} install-sail-riscv ${INSTALL_PREFIX}
# Make it available on PATH.
export PATH=${INSTALL_PREFIX}/sail-riscv/bin:${PATH}

# riscv-arch-tests
${JUST} arch-tests-tgz ${INSTALL_PREFIX}
#${JUST} clean-arch-tests
