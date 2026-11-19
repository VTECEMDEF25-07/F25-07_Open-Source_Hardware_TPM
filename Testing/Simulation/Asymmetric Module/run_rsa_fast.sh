#!/usr/bin/env bash
# Generic full-width local simulation. Vendor-model evidence uses native Questa.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
build="$root/build/rsa-adapter-fast"
mkdir -p "$build"
cp "$root/build/rsa-adapter/slot.hex" "$root/build/rsa-adapter/rsa_vectors.hex" "$build/"
cd "$build"
verilator --version > tool-version.txt
verilator --cc --exe --main --timing --unroll-count 1 -Wno-fatal \
 --top-module tb_rsa_adapter --Mdir obj \
 "$root/Source Code/Key Generation/IP/"*.v \
 "$root/Source Code/Key Generation/rtl/arithmetic/keygen_pair_check.v" \
 "$root/Source Code/Asymmetric Module/"*.v \
 "$root/Source Code/Execution Engine/execution_engine_rsa.v" \
 "$root/Testing/Simulation/Asymmetric Module/tb_rsa_adapter.sv" > elaborate.log 2>&1
g++ -O1 -std=c++20 -pthread -Iobj -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
 obj/*.cpp /usr/share/verilator/include/verilated.cpp /usr/share/verilator/include/verilated_timing.cpp \
 /usr/share/verilator/include/verilated_threads.cpp -o obj/test_rsa > compile.log 2>&1
./obj/test_rsa | tee result.log
grep -q 'RSA_ADAPTER_PASS case=0 backend=0' result.log
