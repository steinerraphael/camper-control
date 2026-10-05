"""Configuration: what is wired where.

The wiring is a property of the van, not of the code, so it lives in YAML.
Adding a light or a sensor should never need a code change.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Annotated, Literal

import yaml
from pydantic import BaseModel, Field, model_validator

DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "config" / "config.example.yaml"


class SwitchConfig(BaseModel):
    id: str
    name: str
    pin: int = Field(description="BCM GPIO number driving the relay or MOSFET")
    # Most cheap relay boards switch on when the input is pulled LOW.
    active_low: bool = True
    # Rough draw in amps. Used by the mock driver and shown in the UI.
    load_a: float = 0.0
    # Lower is shed first when the battery runs low. None: never shed
    # (e.g. a ventilation fan or anything safety-related).
    shed_priority: int | None = None


class Ina226Config(BaseModel):
    type: Literal["ina226"]
    id: str
    name: str
    bus: int = 1
    address: int = 0x40
    shunt_ohms: float = 0.001
    # Nominal capacity. Lets the app estimate the time left; nothing else uses it.
    capacity_ah: float | None = None


class Ds18b20Config(BaseModel):
    type: Literal["ds18b20"]
    id: str
    name: str
    device_id: str = Field(description="1-Wire id, e.g. 28-0123456789ab")


SensorConfig = Annotated[Ina226Config | Ds18b20Config, Field(discriminator="type")]


class ProtectionConfig(BaseModel):
    """Low-voltage load shedding for the house battery."""

    battery_sensor: str
    cutoff_v: float = 11.8
    recover_v: float = 12.6
    # A compressor or the starter motor dips the voltage for a moment.
    # Only a dip that lasts this long counts.
    cutoff_delay_s: float = 30.0

    @model_validator(mode="after")
    def _hysteresis(self) -> ProtectionConfig:
        if self.recover_v <= self.cutoff_v:
            raise ValueError("recover_v must be above cutoff_v, or protection would flap")
        return self


class Config(BaseModel):
    driver: Literal["mock", "pi"] = "mock"
    poll_interval_s: float = 2.0
    switches: list[SwitchConfig] = []
    sensors: list[SensorConfig] = []
    protection: ProtectionConfig | None = None

    @model_validator(mode="after")
    def _consistent(self) -> Config:
        ids = [s.id for s in self.switches] + [s.id for s in self.sensors]
        dupes = {i for i in ids if ids.count(i) > 1}
        if dupes:
            raise ValueError(f"duplicate ids: {sorted(dupes)}")
        pins = [s.pin for s in self.switches]
        dupes_pins = {p for p in pins if pins.count(p) > 1}
        if dupes_pins:
            raise ValueError(f"GPIO pin used twice: {sorted(dupes_pins)}")
        if self.protection:
            battery = next(
                (s for s in self.sensors if s.id == self.protection.battery_sensor), None
            )
            if battery is None or battery.type != "ina226":
                raise ValueError("protection.battery_sensor must name an ina226 sensor")
        return self


def load_config(path: str | Path | None = None) -> Config:
    path = Path(path or os.environ.get("CAMPER_CONFIG") or DEFAULT_CONFIG)
    with path.open(encoding="utf-8") as f:
        return Config.model_validate(yaml.safe_load(f) or {})
