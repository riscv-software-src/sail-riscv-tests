#!/usr/bin/env python3
import os, sys, argparse, tarfile, pathlib

def files_in_tgz(f):
    with tarfile.open(f) as tgz:
        for n in tgz.getnames():
            f = os.path.normpath(n)
            if f == "." or f == "..": continue
            yield f

def test_set_in_tgz(f):
    return set(files_in_tgz(f)) if os.path.isfile(f) else None

def show_testset_difference(opts, test_set, previous, current):
    match test_set_in_tgz(previous), test_set_in_tgz(current):
        case None, None:
            print(f"{test_set} is not present in both releases.")
        case previous, None:
            print(f"{test_set} with {len(previous)} test files was removed.")
        case None, current:
            print(f"{test_set} with {len(current)} test files was added.")
        case previous, current:
            removed, added = (previous - current, current - previous)
            print(f"{test_set} has {len(current)} test files, with {len(added)} added to and {len(removed)} removed from the previous release.")
            if opts.verbose:
                for t in removed: print(f"  removed {t}")
                for t in added: print(f"  added {t}")

def show_release_difference(opts, testsets):
    for set, previous, current in testsets:
        show_testset_difference(opts, set, previous, current)

def get_testsets(prev_release_dir, cur_release_dir):
    testset_names = ["riscv-tests", "riscv-arch-tests"] + [f"riscv-vector-tests-v{vlen}x{xlen}" for vlen in [128, 256, 512] for xlen in [32, 64]]
    testset_filenames = [name + ".tar.gz" for name in testset_names]
    return [(name,
             os.path.join(prev_release_dir, filename),
             os.path.join(cur_release_dir, filename))
            for (name, filename) in zip(testset_names, testset_filenames)]

def make_cli_parser():
    parser = argparse.ArgumentParser(description="Compare testsets from two releases")
    parser.add_argument('-p', '--previous', type=pathlib.Path, required=True, help="directory containing testsets from previous release")
    parser.add_argument('-c', '--current', type=pathlib.Path, required=True, help="directory containing testsets from current release")
    parser.add_argument('-v', '--verbose', action='store_const', const=True, help="show files added or removed")
    return parser

if __name__ == "__main__":
    parser = make_cli_parser()
    cliopts = sys.argv[1:]
    if len(cliopts) == 0:
        parser.print_help()
        sys.exit(0)
    opts = parser.parse_args(cliopts)
    testsets = get_testsets(opts.previous, opts.current)
    show_release_difference(opts, testsets)
