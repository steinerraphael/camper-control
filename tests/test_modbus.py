from __future__ import annotations

import asyncio

import pytest
from pydantic import ValidationError

from camper.config import Config
from camper.hardware.modbus import ModbusError, ModbusOutput, ModbusRtu, crc16, frame


class FakePort:
    """Answers like the relay module, or like a broken line when told to."""

    def __init__(self, replies: list[bytes] | None = None) -> None:
        self.written: list[bytes] = []
        self.coils = [False] * 8
        self._replies = replies

    def write(self, data: bytes) -> None:
        self.written.append(data)
        if data[1] == 0x05 and data[3] < len(self.coils):
            self.coils[data[3]] = data[4] == 0xFF

    def read(self, size: int) -> bytes:
        if self._replies is not None:
            return self._replies.pop(0) if self._replies else b""
        request = self.written[-1]
        if request[1] == 0x01:  # read coils: one byte of bits
            body = bytes((request[0], 0x01, 1, int(self.coils[request[3]])))
            return body + crc16(body)
        return request  # writes are echoed

    def reset_input_buffer(self) -> None:
        pass


def test_frames_match_the_waveshare_manual():
    # Examples from the Waveshare wiki for the Modbus RTU Relay (D).
    assert frame(1, 0x05, 0, 0xFF00) == bytes.fromhex("01 05 00 00 FF 00 8C 3A")
    assert frame(1, 0x01, 0, 8) == bytes.fromhex("01 01 00 00 00 08 3D CC")
    assert frame(1, 0x02, 0, 8) == bytes.fromhex("01 02 00 00 00 08 79 CC")


def test_crc_is_low_byte_first():
    assert crc16(bytes.fromhex("01 05 00 00 FF 00")) == bytes.fromhex("8C 3A")


def test_channel_three_is_coil_two_and_starts_off_in_command_mode():
    port = FakePort()
    out = ModbusOutput(ModbusRtu(port, address=1), channel=3)
    out.set(True)
    assert port.written == [
        frame(1, 0x06, 0x1002, 0x0000),  # DI3 does not touch relay 3
        frame(1, 0x05, 2, 0x0000),
        frame(1, 0x05, 2, 0xFF00),
    ]
    assert out.read() is True


def test_button_puts_the_channel_in_toggle_mode():
    port = FakePort()
    ModbusOutput(ModbusRtu(port, address=1), channel=1, button=True)
    # The manual's linkage example is 01 06 10 00 00 01 4C CA; toggle is value 2.
    assert frame(1, 0x06, 0x1000, 0x0001) == bytes.fromhex("01 06 10 00 00 01 4C CA")
    assert port.written[0] == frame(1, 0x06, 0x1000, 0x0002)


def test_a_button_press_shows_up_in_the_app_state():
    from camper.controller import Controller

    config = Config.model_validate(
        {
            "modbus": {},
            "switches": [{"id": "light", "name": "Licht", "channel": 1, "button": True}],
        }
    )
    port = FakePort()
    out = ModbusOutput(ModbusRtu(port, address=1), channel=1, button=True)
    ctl = Controller(config, {"light": out}, {})
    port.coils[0] = True  # someone pressed S1
    asyncio.run(ctl.poll_once())
    assert ctl.snapshot()["switches"][0]["on"] is True


def test_button_needs_a_channel():
    with pytest.raises(ValidationError, match="button needs a Modbus channel"):
        Config.model_validate({"switches": [{"id": "a", "name": "A", "pin": 17, "button": True}]})


def test_a_silent_module_is_an_error_after_one_retry():
    port = FakePort(replies=[])
    with pytest.raises(ModbusError, match="did not answer"):
        ModbusRtu(port, address=1).write_coil(0, True)
    assert len(port.written) == 2


def test_one_garbled_answer_is_retried():
    request = frame(1, 0x05, 0, 0xFF00)
    garbled = request[:-1] + b"\x00"
    port = FakePort(replies=[garbled, request])
    ModbusRtu(port, address=1).write_coil(0, True)
    assert len(port.written) == 2


def test_exception_reply_is_reported():
    body = bytes((1, 0x85, 0x02))
    port = FakePort(replies=[body + crc16(body)] * 2)
    with pytest.raises(ModbusError, match="refused"):
        ModbusRtu(port, address=1).write_coil(9, True)


def test_switch_needs_exactly_one_of_pin_and_channel():
    with pytest.raises(ValidationError, match="either pin or channel"):
        Config.model_validate({"switches": [{"id": "a", "name": "A"}]})
    with pytest.raises(ValidationError, match="either pin or channel"):
        Config.model_validate(
            {"modbus": {}, "switches": [{"id": "a", "name": "A", "pin": 17, "channel": 1}]}
        )


def test_channels_need_a_modbus_section_and_are_unique():
    with pytest.raises(ValidationError, match="no modbus section"):
        Config.model_validate({"switches": [{"id": "a", "name": "A", "channel": 1}]})
    with pytest.raises(ValidationError, match="channel used twice"):
        Config.model_validate(
            {
                "modbus": {},
                "switches": [
                    {"id": "a", "name": "A", "channel": 1},
                    {"id": "b", "name": "B", "channel": 1},
                ],
            }
        )


def test_a_modbus_config_runs_on_the_mock_driver():
    from camper.controller import Controller
    from camper.hardware import build_hardware

    config = Config.model_validate(
        {
            "modbus": {"port": "/dev/ttyUSB0"},
            "switches": [{"id": "pump", "name": "Wasserpumpe", "channel": 3}],
        }
    )
    ctl = Controller(config, *build_hardware(config))
    ctl.set_switch("pump", True)
    assert ctl.snapshot()["switches"][0]["on"] is True
