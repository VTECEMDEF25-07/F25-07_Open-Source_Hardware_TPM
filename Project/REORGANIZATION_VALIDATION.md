# Layout verification — November 3, 2026

Author: Aaron Grossman

Historical record: the custom fan implementation tested below has since been replaced by the original Terasic example. Its fault/guard results and bitstream hashes do not validate the vendor-example revision. See `Project/DE25/Fan Controller/README.md` from the repository root for the current source contract.

The Project / Source Code / Simulation reorganization changes paths, runners, documentation and ignore rules. All 50 relocated HDL, testbench, C/header and PDF reference files match their previous Git blobs byte for byte. No hardware logic was changed.

- Both board selectors resolve every listed source and timing input.
- DE1: full Quartus Lite 24.1 compile passes; 912 ALMs, 4 RAM blocks, 1 PLL. Selector verifies physical pins and the programming file.
- DE25: full Quartus Pro 26.1 compile passes; selector verifies physical pins and the programming file; 2 RAM blocks, 1 PLL. Its inherited worst setup slack remains -2.700 ns; timing signoff is not established.
- DE1 and DE25: existing 1 MHz SPI legacy acceptance vectors pass using local test-only board/ideal PLL adapters. This does not validate physical hardware or vendor PLL simulation.
- Relocated DE25 decoded fan and serial I2C fan regressions both pass, including startup, invalid/stale samples and eight bus fault/recovery cases.
- Project settings, constraints and simulation test inputs remain tracked. Generated outputs and pin dumps are ignored. Original pin dumps are retained outside the checkout in class-workspace AI/tmp/pr36-generated-evidence.

Class-workspace evidence: AI/tmp/pr36-de1-build.log, pr36-de25-build-retry.log, pr36-fan-check/, pr36-fan-bus-check/, pr36-spi-DE1/ and pr36-spi-DE25/.

Legacy module benches are preserved, not newly certified as independent acceptance tests. No physical-board testing or programming was performed. Historical VALIDATION.md records remain historical; generated files are not committed.
