# Simulation

Author: Aaron Grossman

Module-named folders preserve the original module testbenches. These legacy benches are retained as supplied; they are not all automated acceptance tests.

DE25 cooling regressions require Linux/WSL, Verilator and g++:

```text
python3 Testing/Simulation/DE25/simulate_fan.py --build /absolute/scratch/fan
python3 Testing/Simulation/DE25/simulate_fan_bus.py --build /absolute/scratch/fan-bus
```

These runners now check the unmodified vendor AutoFan behavior and normal serial I2C configuration/telemetry. Previous custom staleness, one-shot conversion and fault/recovery tests were replaced with these example-compatible checks.

The scripts reference board hardware under Project/DE25/Fan Controller. Keep generated results outside source folders. Required test models and fixtures are tracked.

See [RNG simulations](RNG%20Module/README.md) for the two relocated PR #38 benches. Their serial capture hardware assets are under `Testing/Hardware/DE25/Entropy Capture/`.
