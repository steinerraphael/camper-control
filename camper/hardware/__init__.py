"""Builds the configured drivers. Nothing outside this package picks a driver."""

from __future__ import annotations

from ..config import Config, Ds18b20Config, Ina226Config
from .base import Output, Sensor
from .mock import MockBattery, MockOutput, MockThermometer

__all__ = ["Output", "Sensor", "build_hardware"]


def build_hardware(config: Config) -> tuple[dict[str, Output], dict[str, Sensor]]:
    if config.driver == "pi":
        return _build_pi(config)
    return _build_mock(config)


def _build_mock(config: Config) -> tuple[dict[str, Output], dict[str, Sensor]]:
    mock_outputs = {s.id: MockOutput() for s in config.switches}
    loads = {s.id: (mock_outputs[s.id], s.load_a) for s in config.switches}
    sensors: dict[str, Sensor] = {}
    temperatures = iter([19.0, 5.0, 12.0, 25.0])  # cabin, fridge, then anything
    for s in config.sensors:
        if isinstance(s, Ina226Config):
            sensors[s.id] = MockBattery(loads)
        else:
            sensors[s.id] = MockThermometer(base=next(temperatures, 15.0))
    return dict(mock_outputs), sensors


def _build_pi(config: Config) -> tuple[dict[str, Output], dict[str, Sensor]]:
    from .pi import Ds18b20, GpioOutput, Ina226

    outputs: dict[str, Output] = {s.id: GpioOutput(s.pin, s.active_low) for s in config.switches}
    sensors: dict[str, Sensor] = {}
    for s in config.sensors:
        if isinstance(s, Ina226Config):
            sensors[s.id] = Ina226(s.bus, s.address, s.shunt_ohms)
        elif isinstance(s, Ds18b20Config):
            sensors[s.id] = Ds18b20(s.device_id)
    return outputs, sensors
