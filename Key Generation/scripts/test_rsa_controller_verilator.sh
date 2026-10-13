#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 ]]; then echo "Usage: $0 ABSOLUTE_BUILD_DIR ABSOLUTE_CONTROLLER_SOURCE" >&2; exit 2; fi
source_root=$(cd "$(dirname "$0")/.." && pwd)
build_dir=$1
mkdir -p "$build_dir"
# Snapshot the reviewed canonical RTL without modifying or tracking its source.
cp "$2" "$build_dir/keygen_rsa_controller.v"
sha256sum "$build_dir/keygen_rsa_controller.v" > "$build_dir/source.sha256"
cd "$build_dir"
verilator --cc --exe --main --timing -Wno-fatal --top-module tb_keygen_rsa_controller --Mdir obj \
  "$build_dir/keygen_rsa_controller.v" "$source_root/testbench/tb_keygen_rsa_controller.sv" > elaborate.log 2>&1
g++ -O1 -std=c++20 -pthread -Iobj -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
  obj/*.cpp /usr/share/verilator/include/verilated.cpp /usr/share/verilator/include/verilated_timing.cpp \
  /usr/share/verilator/include/verilated_threads.cpp -o obj/test_rsa_controller > compile.log 2>&1
./obj/test_rsa_controller | tee result.log
grep -q 'PASS RSA controller:' result.log
