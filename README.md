<!-- Authors: Aaron Grossman (changes in this PR); existing project contributors; see Git history. -->
# Open-source hardware TPM

Virginia Tech Lenovo-sponsored senior design project.

## Phase 2 Expo demo scope

This fully AI-developed demo is intended to show the individual functionality of the team's five cryptographic modules. Those modules are the team's work.

**Treat the integration code that connects the modules as unverified.** A passing expo demonstration covers only the flows exercised on stage. This branch is a poor starting point for further TPM integration. Continue production integration from the team's reviewed development branch.

## Run the combined DE25 demo

Power the DE25 from its board supply and load the combined FPGA image with its matching HPS display firmware. Connect the FT232H USB-to-SPI adapter and the Nucleo panel to the laptop. After programming, disconnect the DE25 programming/serial USB cable for the display test.

On Windows, double-click **Start Lenovo Demo.cmd**. The window controls SHA-256, AES and RSA. The physical buttons select the original boot message or a one-byte change. AES and RSA send ciphertext over SPI for FPGA decryption. The HPS reads the result through the internal bridge and drives the blue LCD.

### Nucleo panel connections

Use the **NUCLEO-L452RE-P** board profile when building the panel sketch. Both the P and non-P models can appear as NODE_L452RE on Windows. Connect the Nucleo's ST-LINK USB port to the laptop. The serial link runs at 115200 baud, 8N1.

| Part | Arduino header pin on the -P board | Connection |
|---|---|---|
| Normal Boot button | D2 (PA12) | Momentary switch to Nucleo GND |
| Change One Byte button | D3 (PB3) | Momentary switch to Nucleo GND |
| Green LED | D8 (PB6) | Series resistor and LED to Nucleo GND |
| Red LED | D9 (PA8) | Series resistor and LED to Nucleo GND |

The sketch enables internal pull-ups on D2 and D3. Pressing a switch grounds the corresponding input. The FT232H USB-to-SPI adapter connects the laptop to the DE25 separately.

## Layout

- `Project/DE1/`: DE1-SoC Quartus project, board wrapper, pins and constraints (direct 50 MHz, no PLL).
- `Project/DE25/`: DE25 Quartus project, board wrapper, PLL, pins, constraints and Fan Controller.
- `Source Code/`: shared TPM top and reusable module folders, including the standalone RNG sources.
- `Testing/Simulation/`: module testbenches, RNG benches and DE25 cooling regression scripts/models.
- `Testing/Hardware/`: physical-board capture assets, host testers and testing procedures.

## Open and compile

1. Open the board's Quartus project:
   - DE1-SoC: `Project/DE1/de1_soc_top.qpf` in Quartus Lite/Standard with Cyclone V support.
   - DE25 Standard RevD: `Project/DE25/de25_soc_top.qpf` in Quartus Pro 26.1 with Agilex 5 support.
2. Select **Processing > Start Compilation** in Quartus.

Keep the complete repository together: project source paths are relative. Generated outputs are ignored; source, constraints, project settings and required test inputs remain tracked.

## DE25 SPI wiring configuration

Set `DE25_SPI_TARGET` on line 8 of [`Project/DE25/de25_spi_pins.tcl`](Project/DE25/de25_spi_pins.tcl) before compiling:

```tcl
set DE25_SPI_TARGET usb_adapter
```

- `usb_adapter` (default): USB-to-SPI adapter on the even-numbered JP1 signal contacts.
- `lenovo_tester`: Raspberry Pi running Lenovo's TPM tester on the adjacent odd-numbered JP1 signal contacts.

Change the setting, recompile `Project/DE25/de25_soc_top.qpf`, and program the resulting SOF. The setting selects physical pins through Quartus Tcl constraints; it is separate from the HDL `FPGA_IP_TYPE` resource selection. See the [DE25 wiring table](Project/DE25/README.md#spi-wiring-selection) for connector pins and Pi connections. The Lenovo pin map still requires physical validation.

The [common SPI guide](Source%20Code/IO%20Interface/SPI.md) defines host timing and test commands.

See [board setup](Project/README.md) for board details and [simulation instructions](Testing/Simulation/README.md) for simulations. Each board's VALIDATION.md records build results and timing/hardware limitations.

Key generation: [design and review](Source%20Code/Key%20Generation/README.md), [simulation runners](Testing/Simulation/Key%20Generation/README.md). The portable core remains separate from TPM command integration.
