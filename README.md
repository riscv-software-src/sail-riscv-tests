# Test suites for the Sail RISC-V formal model
## About
 This repository provides precompiled test suites as releases for comprehensive testing of the [Sail RISC-V model](https://github.com/riscv/sail-riscv). The tests are built from the following source repositories:
 - [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
 - [riscv-vector-tests](https://github.com/chipsalliance/riscv-vector-tests)
 - [riscv-arch-test](https://github.com/riscv/riscv-arch-test)

Note that `riscv-arch-test` requires an installation of `mise`.  Please see its [installation instructions](https://mise.jdx.dev/getting-started.html).  Make sure it is activated before building the test suites.

## Adding a new test suite

Here are some guidelines on adding a new suite.

1. Add a recipe to the [`justfile`](./justfile) to download and build
   a compressed bundle (typically a `.tar.gz`) containing the binaries
   of the test suite.  See the existing recipes for examples.

2. Test the built suite against the Sail model.  This involves
   updating `test/CMakeLists.txt` to include the new test suite gated
   by a new test option.  The download step can be bypassed by putting
   the built testsuite bundle in the test subdirectory of a build
   directory of the Sail model.

3. Add the test suite to the CI of this repository as a new job in the
   `build.yml` workflow, and update the `release` workflow to mention
   any relevant upstream versions.

4. Add this suite to the [`compare-releases.py`](./compare-releases.py) script.

## Project Licensing

This project has multiple licenses associated with it. All work contributed solely to this repo, not included by git submodule, is licensed under the project [LICENSE](LICENSE) file. Submodules included in the project all contain their individual license files that govern their contents.
