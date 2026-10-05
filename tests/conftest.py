from __future__ import annotations

import pytest

from camper.config import Config, load_config
from camper.controller import Controller
from camper.hardware import build_hardware
from camper.hardware.mock import MockBattery


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def config() -> Config:
    return load_config()  # the example config, mock driver


@pytest.fixture
def clock() -> FakeClock:
    return FakeClock()


@pytest.fixture
def controller(config: Config, clock: FakeClock) -> Controller:
    outputs, sensors = build_hardware(config)
    return Controller(config, outputs, sensors, clock=clock)


@pytest.fixture
def battery(controller: Controller) -> MockBattery:
    b = controller._sensors["house_battery"]
    assert isinstance(b, MockBattery)
    return b
