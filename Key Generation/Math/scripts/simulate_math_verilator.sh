#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo "Usage: $0 ABSOLUTE_SCRATCH_DIRECTORY" >&2; exit 2; fi
source_root=$(cd "$(dirname "$0")/../.." && pwd)
build_dir=$1
mkdir -p "$build_dir"
python3 "$source_root/Math/scripts/generate_vectors.py" "$build_dir/vectors.txt" --full --max-limbs 32
cd "$build_dir"
verilator --cc --exe --main --timing -Wno-fatal --top-module tb_keygen_math \
  -DKEYGEN_MATH_SMALL --Mdir obj \
  "$source_root"/IP/*.v "$source_root/rtl/arithmetic/keygen_math.v" \
  "$source_root/Math/tests/tb_keygen_math.sv" > "$build_dir/build.log" 2>&1
# Direct compiler invocation avoids GNU Make's prohibition on spaces in CURDIR.
g++ -O2 -std=c++20 -pthread -Iobj -I/usr/share/verilator/include \
  -I/usr/share/verilator/include/vltstd obj/*.cpp \
  /usr/share/verilator/include/verilated.cpp \
  /usr/share/verilator/include/verilated_timing.cpp \
  /usr/share/verilator/include/verilated_threads.cpp \
  -o obj/Vtb_keygen_math >> "$build_dir/build.log" 2>&1
(cd "$build_dir" && ./obj/Vtb_keygen_math) | tee "$build_dir/math.log"
grep -q 'PASS math:' "$build_dir/math.log"
