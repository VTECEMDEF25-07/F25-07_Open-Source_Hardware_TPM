# Simulation

Module-named folders preserve the original module testbenches. These legacy benches are retained as supplied; they are not all automated acceptance tests.

DE25 cooling regressions require Linux/WSL, Verilator and g++:

```text
python3 Simulation/DE25/simulate_fan.py --build /absolute/scratch/fan
python3 Simulation/DE25/simulate_fan_bus.py --build /absolute/scratch/fan-bus
```

The scripts reference board hardware under Project/DE25/Fan Controller. Keep generated results outside source folders. Required test models and fixtures are tracked.

Common SPI unit/protocol regressions and exact 24/30 MHz examples are in
[the SPI guide](../Source%20Code/IO%20Interface/SPI.md). They use Questa with
portable RTL and ideal board models. Original protocol assertions are retained.
