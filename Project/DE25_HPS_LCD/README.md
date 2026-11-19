# DE25 RevD HPS LCD and FPGA display registers

The HPS drives the ST7567 using the dedicated LCD pins and reads crypto results through its 32-bit lightweight HPS-to-FPGA bridge. The FPGA side uses the same 50 MHz PLL clock as the crypto engines. Platform Designer connects the HPS reset output to the lightweight AXI reset input. Each Avalon read returns a registered response one clock after acceptance.

The HPS window starts at physical address 0x20000000. All entries below are 32-bit little-endian words.

| Word | Contents |
| --- | --- |
| 0 | Signature 0x444C4344 |
| 1 | Result revision |
| 2 | Completed decryption operation ID |
| 3 | Algorithm in bits 10 through 8 (2 for AES, 4 for RSA), displayed byte count in bits 7 through 0 |
| 4–6 | Current status word, operation ID and status sequence |
| 8–39 | Up to 126 recovered message bytes, packed low byte first |

Read the revision and status sequence before and after the payload to detect an overlapping update. Successful AES and validated RSA decryption publish the displayed bytes. Out-of-range payload lanes read zero. Writes have no effect.

The DE25 project's QSF includes both the system QIP and the generated HPS, clock and Avalon bridge QIPs. The generated XML, QIP and handoff document the fitted design inputs. Run the following commands from this directory to generate synthesis sources and check the handoff in Quartus Pro 26.1.

~~~powershell
qsys-script --quartus-project=hps_lcd_subsys.qpf --script=generate_hps_lcd.tcl --jvm-max-heap-size=512m
qsys-generate hps_lcd_subsys.qsys --synthesis=VERILOG --parallel=off --quartus-project=hps_lcd_subsys.qpf --jvm-max-heap-size=512m
python audit_handoff.py
~~~

The audit checks the nine dedicated pins, pinmux selections, 1.8 V settings, clock handoff, disabled DDR, and enabled 32-bit lightweight bridge. The bare-metal firmware consumes the derived handoff facts during initialization.
