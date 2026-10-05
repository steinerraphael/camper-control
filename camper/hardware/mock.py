"""Simulated hardware, so the whole stack runs on a laptop without a Pi."""

from __future__ import annotations

import random

from .base import Output, Sensor


class MockOutput(Output):
    def __init__(self) -> None:
        self.on = False

    def set(self, on: bool) -> None:
        self.on = on


class MockBattery(Sensor):
    """A battery whose voltage sags with the switched load.

    `voltage_override` lets tests (and a curious developer) force a value.
    """

    def __init__(self, outputs: dict[str, tuple[MockOutput, float]]) -> None:
        self._outputs = outputs
        self.voltage_override: float | None = None

    def read(self) -> dict[str, float]:
        current = sum(load for out, load in self._outputs.values() if out.on)
        if self.voltage_override is not None:
            voltage = self.voltage_override
        else:
            voltage = 12.9 - 0.03 * current + random.uniform(-0.02, 0.02)
        return {
            "voltage": round(voltage, 2),
            "current": round(-current, 2),  # negative: discharging
            "power": round(-voltage * current, 1),
        }


class MockThermometer(Sensor):
    def __init__(self, base: float) -> None:
        self._base = base

    def read(self) -> dict[str, float]:
        return {"temperature": round(self._base + random.uniform(-0.3, 0.3), 1)}
