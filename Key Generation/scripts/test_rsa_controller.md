# Dedicated RSA controller regression

Run `test_rsa_controller_verilator.sh ABSOLUTE_BUILD_DIRECTORY ABSOLUTE_CONTROLLER_SOURCE` under WSL/Linux with Verilator, g++, and a writable class scratch directory. The runner copies the chosen controller into the build directory and records its SHA-256, so uncommitted integration source can be tested without modifying it. Paths with spaces are supported. No FPGA or SPI device is accessed.

The service peer is scripted: it supplies control predicates and checks every accepted opcode and all four arguments against the sequence in `docs/RSA_ALGORITHM.md` and `firmware/rsa_control.c`. This is not an arithmetic model or proof of primality. The DUT has no test-only state forcing or reduced retry bounds. Tests cover:

- Five accepted witness rounds per prime, rejected witnesses, repeated square/copy/check cycles, and low-d restart of both prime searches.
- Actual p and q exhaustion after 10,240 and 20,480 failed candidates; non-counting range/separation redraws at the boundary and independence of the q budget from prior p failures.
- Source and arithmetic fault mapping at all command stages, first terminal completion held against later responses, command backpressure, stray response rejection, and reset while command/response are pending.
- Real 50,000,000-cycle internal response and command-admission watchdogs, external DRAW waiting longer than that limit, and service-fault response priority on the exact timeout edge.

Controller tests cannot establish service-side range/filter/Miller-Rabin arithmetic or whole-core cleanup priority. Independent code review confirms the service's initial a-1 square budget, decrement following nonterminal squares, and w-1 acceptance before exhaustion match the reference. The original services test fixture has a=1 and does not dynamically exercise repeated squaring; that coverage requires a separate services test. Whole-key known-answer replay and board tests remain separate gates.
