from __future__ import annotations

import pytest
from pydantic import ValidationError

from camper.config import Config


def test_example_config_loads(config):
    assert config.driver == "mock"
    assert config.protection is not None


def test_pin_used_twice_is_rejected():
    with pytest.raises(ValidationError, match="GPIO pin used twice"):
        Config.model_validate(
            {"switches": [{"id": "a", "name": "A", "pin": 17}, {"id": "b", "name": "B", "pin": 17}]}
        )


def test_protection_without_hysteresis_is_rejected():
    with pytest.raises(ValidationError, match="recover_v"):
        Config.model_validate(
            {
                "sensors": [{"type": "ina226", "id": "bat", "name": "B"}],
                "protection": {"battery_sensor": "bat", "cutoff_v": 12.0, "recover_v": 11.9},
            }
        )


def test_protection_must_name_a_battery_sensor():
    with pytest.raises(ValidationError, match="battery_sensor"):
        Config.model_validate(
            {
                "sensors": [{"type": "ds18b20", "id": "t", "name": "T", "device_id": "28-x"}],
                "protection": {"battery_sensor": "t"},
            }
        )
