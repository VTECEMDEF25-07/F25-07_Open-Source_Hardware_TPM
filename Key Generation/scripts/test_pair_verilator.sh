#!/usr/bin/env bash
# Filename: test_pair_verilator.sh
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Checks pair verilator behavior and reports failures.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

set -euo pipefail
if [[ $# -ne 2 ]]; then echo "Usage: $0 ABSOLUTE_BUILD_DIRECTORY ABSOLUTE_CORPUS_JSON" >&2;exit 2;fi
source_root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
build_dir=$1
python3 "$source_root/reference/pair_vectors.py" "$build_dir/pair_vectors.mem" --corpus "$2"
cd "$build_dir"
verilator --cc --exe --main --timing --unroll-count 1 -Wno-fatal --top-module tb_keygen_pair_check --Mdir obj \
 "$source_root"/IP/*.v "$source_root/rtl/arithmetic/keygen_pair_check.v" "$source_root/testbench/tb_keygen_pair_check.sv" > elaborate.log 2>&1
g++ -O1 -std=c++20 -pthread -Iobj -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
 obj/*.cpp /usr/share/verilator/include/verilated.cpp /usr/share/verilator/include/verilated_timing.cpp /usr/share/verilator/include/verilated_threads.cpp \
 -o obj/test_pair > compile.log 2>&1
./obj/test_pair | tee result.log
grep -q 'PASS pair check:' result.log
