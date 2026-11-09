# Filename: de25_spi_pins.tcl
# Author: Aaron Grossman
# Date: 2026-11-08
# General Description: Selects the DE25 RevD SPI connector wiring at build time.
# AI Disclosure: Codex assisted with coding and verification.

# Change this one setting, then recompile: usb_adapter or lenovo_tester.
set DE25_SPI_TARGET usb_adapter

# JP1 contact numbers are physical pins, not GPIO indexes.
# Source: shared "DE1-SOC Pin Assignments" document, DE25 sections:
# https://docs.google.com/document/d/1Eylg2XuQ-H1bI_WXwmYC9IKuTvtMnYH5k5sPCp9v7NM/edit
# Package pins checked against Terasic's DE25 Standard RevD golden_top.qsf.
switch -- $DE25_SPI_TARGET {
    usb_adapter {
        set_location_assignment PIN_BF40 -to spi_miso_o;    # JP1 4, GPIO_D[3]
        set_location_assignment PIN_BM31 -to spi_mosi_i;    # JP1 6, GPIO_D[5]
        set_location_assignment PIN_BP31 -to spi_cs_n_i;    # JP1 8, GPIO_D[7]
        set_location_assignment PIN_BU28 -to spi_clock_i;   # JP1 10, GPIO_D[9]
        set_location_assignment PIN_BW28 -to spi_reset_n_i; # JP1 14, GPIO_D[11]
    }
    lenovo_tester {
        set_location_assignment PIN_BF29 -to spi_miso_o;    # JP1 3, GPIO_D[2]
        set_location_assignment PIN_BK28 -to spi_mosi_i;    # JP1 5, GPIO_D[4]
        set_location_assignment PIN_BM28 -to spi_cs_n_i;    # JP1 7, GPIO_D[6]
        set_location_assignment PIN_BR31 -to spi_clock_i;   # JP1 9, GPIO_D[8]
        set_location_assignment PIN_BU31 -to spi_reset_n_i; # JP1 13, GPIO_D[10]
    }
    default {
        error "DE25_SPI_TARGET must be usb_adapter or lenovo_tester (got '$DE25_SPI_TARGET')"
    }
}
