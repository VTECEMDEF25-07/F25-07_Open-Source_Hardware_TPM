# Filename: fan_diagnostics.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Decode read-only fan diagnostic register version 1.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Decode read-only fan diagnostic register version 1."""


def read_diagnostics(adapter):
    flags, sensor, identity = (adapter.register(index) for index in (32, 33, 34))
    names = ("ack", "identity", "conversion_timeout", "not_valid", "open_diode",
             "negative_temperature", "guard", "preflight_config")
    return {"fan_diagnostic_flags": flags,
            "fan_fault_reasons": [name for index, name in enumerate(names) if flags & (1 << index)],
            "conversion_wait": bool(flags & 256), "raw_sensor_status": (sensor >> 8) & 255,
            "remote2_high": (sensor >> 16) & 255, "remote2_low": (sensor >> 24) & 255,
            "manufacturer": (identity >> 24) & 255, "device": (identity >> 16) & 255,
            "local_low": (identity >> 8) & 255, "remote1_low": identity & 255}
