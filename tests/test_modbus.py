from __future__ import annotations

import pytest
from pydantic import ValidationError

from camper.config import Config
from camper.hardware.modbus import ModbusError, ModbusOutput, ModbusRtu, crc16, frame


class FakePort:
    """Answers like the relay module, or like a broken line when told to."""

    def __init__(self, replies: list[bytes] | None = None) -> None:
        self.written: list[bytes] = []
        self._replies = replies

    def write(self, data: bytes) -> None:
        self.written.append(data)

    def read(self, size: int) -> bytes:
        if self._replies is None:
            return self.written[-1]  # healthy module: echo
        return self._replies.pop(0) if self._replies else b""

    def reset_input_buffer(self) -> None:
        pass


def test_frames_match_the_waveshare_manual():
    # Examples from the Waveshare wiki for the Modbus RTU Relay (D).
    assert frame(1, 0x05, 0, 0xFF00) == bytes.fromhex("01 05 00 00 FF 00 8C 3A")
    assert frame(1, 0x01, 0, 8) == bytes.fromhex("01 01 00 00 00 08 3D CC")
    assert frame(1, 0x02, 0, 8) == bytes.fromhex("01 02 00 00 00 08 79 CC")


def test_crc_is_low_byte_first():
    assert crc16(bytes.fromhex("01 05 00 00 FF 00")) == bytes.fromhex("8C 3A")


def test_channel_one_is_coil_zero_and_starts_off():
    port = FakePort()
    out = ModbusOutput(ModbusRtu(port, address=1), channel=3)
    out.set(True)
    assert port.written == [frame(1, 0x05, 2, 0x0000), frame(1, 0x05, 2, 0xFF00)]


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
