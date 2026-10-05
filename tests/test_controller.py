from __future__ import annotations

import pytest

from camper.controller import Controller, SwitchLocked, UnknownSwitch
from camper.hardware.base import Sensor


def switch(ctl: Controller, switch_id: str) -> dict:
    return next(s for s in ctl.snapshot()["switches"] if s["id"] == switch_id)


def test_everything_starts_off(controller):
    assert all(not s["on"] for s in controller.snapshot()["switches"])


def test_switching_reaches_the_output(controller):
    controller.set_switch("water_pump", True)
    assert switch(controller, "water_pump")["on"]
    assert controller._outputs["water_pump"].on


def test_unknown_switch(controller):
    with pytest.raises(UnknownSwitch):
        controller.set_switch("jacuzzi", True)


async def test_short_dip_does_not_shed(controller, battery, clock):
    controller.set_switch("water_pump", True)
    battery.voltage_override = 11.0  # compressor start
    await controller.poll_once()
    clock.now = 10
    battery.voltage_override = 12.7
    await controller.poll_once()
    clock.now = 60
    await controller.poll_once()
    assert switch(controller, "water_pump")["on"]
    assert not controller.snapshot()["protection"]["active"]


async def test_sustained_low_voltage_sheds_and_locks(controller, battery, clock):
    controller.set_switch("water_pump", True)
    controller.set_switch("bed_light", True)
    battery.voltage_override = 11.5
    await controller.poll_once()
    clock.now = 31
    await controller.poll_once()

    assert controller.snapshot()["protection"]["active"]
    assert not switch(controller, "water_pump")["on"]
    assert switch(controller, "water_pump")["locked"]
    # No shed_priority: the bed light stays on.
    assert switch(controller, "bed_light")["on"]
    with pytest.raises(SwitchLocked):
        controller.set_switch("water_pump", True)
    # Switching off is always allowed.
    controller.set_switch("bed_light", False)


async def test_recovery_unlocks_without_switching_back_on(controller, battery, clock):
    controller.set_switch("water_pump", True)
    battery.voltage_override = 11.5
    await controller.poll_once()
    clock.now = 31
    await controller.poll_once()

    battery.voltage_override = 12.5  # above cutoff, below recover: stays locked
    await controller.poll_once()
    assert switch(controller, "water_pump")["locked"]

    battery.voltage_override = 13.4  # charging
    await controller.poll_once()
    assert not controller.snapshot()["protection"]["active"]
    assert not switch(controller, "water_pump")["locked"]
    assert not switch(controller, "water_pump")["on"]
    controller.set_switch("water_pump", True)


async def test_failing_battery_sensor_does_not_trigger_protection(controller, clock):
    class Broken(Sensor):
        def read(self) -> dict[str, float]:
            raise OSError("I2C bus error")

    controller._sensors["house_battery"] = Broken()
    controller.set_switch("water_pump", True)
    await controller.poll_once()
    clock.now = 100
    await controller.poll_once()

    snap = controller.snapshot()
    battery = next(s for s in snap["sensors"] if s["id"] == "house_battery")
    assert battery["error"] == "I2C bus error"
    assert not snap["protection"]["active"]
    assert switch(controller, "water_pump")["on"]


async def test_subscribers_get_pushed_state(controller):
    q = controller.subscribe()
    controller.set_switch("bed_usb", True)
    snap = q.get_nowait()
    assert next(s for s in snap["switches"] if s["id"] == "bed_usb")["on"]


async def test_hand_switching_is_picked_up(controller):
    controller._outputs["bed_usb"].on = True  # as if a pushbutton had switched it
    controller._outputs["bed_usb"].read = lambda: controller._outputs["bed_usb"].on
    await controller.poll_once()
    assert switch(controller, "bed_usb")["on"]


async def test_hand_switching_cannot_beat_the_protection(controller, battery, clock):
    pump = controller._outputs["water_pump"]
    pump.read = lambda: pump.on
    battery.voltage_override = 11.5
    await controller.poll_once()
    clock.now = 31
    await controller.poll_once()
    assert switch(controller, "water_pump")["locked"]

    pump.on = True  # pushbutton pressed while locked
    await controller.poll_once()
    assert pump.on is False
    assert not switch(controller, "water_pump")["on"]
