# Firmware toolchain

Pinned portable compiler: xPack GNU RISC-V Embedded GCC 15.2.0-1 for Windows x64.
Upstream release: https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/tag/v15.2.0-1
Archive: `xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip`.
SHA-256: `85ef714dacd273b1dadf4af4892774520ac01915bfa6da816a56e7e41591e09e`.

Download/unpack into a local dependency directory, retaining packaged licenses. This project does not redistribute the toolchain or change PATH/global installation. Pass its `bin` directory explicitly to `run_rsa_sim.ps1` / `run_rsa_synthesis.ps1` as `-Toolchain`.

The build uses RV32I/ILP32, no compressed instructions, no M extension, freestanding/no runtime library, no relaxation, no small-data global-pointer addressing, and treats C compiler warnings as errors. Startup establishes a RAM stack and initializes data/BSS. The linker reserves at least 4 KiB for stack and rejects ROM/RAM overflow. This is an allocation limit, not dynamic worst-case stack analysis. Generated ELF/bin/hex/map and image hash manifest remain build artifacts; source and reviewed expected manifest are tracked.

Current control firmware: 1648 bytes text, 0 initialized data, 0 BSS. It contains no cryptographic arithmetic or secret operand buffers; it drives shared RSA services. The 24-instruction feasibility boot remains separately buildable with its small deterministic assembler.
