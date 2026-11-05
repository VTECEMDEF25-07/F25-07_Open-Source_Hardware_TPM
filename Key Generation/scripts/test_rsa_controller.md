<!--
Filename: test_rsa_controller.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Dedicated RSA controller regression.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Dedicated RSA controller regression

Run `test_rsa_controller_verilator.sh ABSOLUTE_BUILD_DIRECTORY ABSOLUTE_CONTROLLER_SOURCE` under WSL/Linux with Verilator, g++, and a writable class scratch directory. The runner copies the chosen controller into the build directory and records its SHA-256, so uncommitted integration source can be tested without modifying it. Paths with spaces are supported. No FPGA or SPI device is accessed.

The service peer is scripted: it supplies control predicates and checks every accepted opcode and all four arguments against the sequence in `docs/RSA_ALGORITHM.md`. This is not an arithmetic model or proof of primality. The DUT has no test-only state forcing or reduced retry bounds. Tests cover:

- Five accepted witness rounds per prime, rejected witnesses, repeated square/copy/check cycles, and low-d restart of both prime searches.
- Actual p and q exhaustion after 10,240 and 20,480 failed candidates; non-counting range/separation redraws at the boundary and independence of the q budget from prior p failures.
- Source and arithmetic fault mapping at all command stages, first terminal completion held against later responses, command backpressure, stray response rejection, and reset while command/response are pending.
- Real 50,000,000-cycle internal response and command-admission watchdogs, external DRAW waiting longer than that limit, and service-fault response priority on the exact timeout edge.

Controller tests cannot establish service-side range/filter/Miller-Rabin arithmetic or whole-core cleanup priority. Independent code review confirms the service's initial a-1 square budget, decrement following nonterminal squares, and w-1 acceptance before exhaustion match the reference. The separate 49-check services suite includes a candidate with a=9 to exercise all eight permitted squares, exact separation and witness boundaries. Whole-key known-answer replay and board tests remain separate gates.

Final regression passed 61,726 checked descriptors across 20 jobs using the real retry and watchdog limits. Evidence is in the class workspace's `AI/tmp/keygen-controller-final/`, including the tested source SHA-256.
