"""Relay modules on an RS485 bus, spoken to in Modbus RTU.

Written against the Waveshare Modbus RTU Relay (D): coil 0-7 are relays
1-8; function 05 switches one, 01 reads them back. Register 0x1000-0x1007
sets what the module's own inputs DI1-DI8 do to the relay of the same
number - 2 makes a pushbutton toggle it, without the Pi.

The framing is done here rather than through a Modbus library: it is three
request types and a CRC, and the libraries have changed their APIs often
enough that pinning one costs more than these lines do.
"""

from __future__ import annotations

import threading
from typing import Any, Protocol

from .base import Output

READ_COILS = 0x01
WRITE_SINGLE_COIL = 0x05
WRITE_REGISTER = 0x06
COIL_ON = 0xFF00
COIL_OFF = 0x0000
INPUT_MODE_BASE = 0x1000
MODE_COMMAND_ONLY = 0x0000
MODE_TOGGLE = 0x0002


def crc16(data: bytes) -> bytes:
    """Modbus CRC-16, low byte first as it goes on the wire."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return bytes((crc & 0xFF, crc >> 8))


def frame(address: int, function: int, a: int, b: int) -> bytes:
    body = bytes((address, function, a >> 8, a & 0xFF, b >> 8, b & 0xFF))
    return body + crc16(body)


class SerialPort(Protocol):
    def write(self, data: bytes) -> Any: ...
    def read(self, size: int) -> bytes: ...
    def reset_input_buffer(self) -> None: ...


class ModbusError(OSError):
    pass


class ModbusRtu:
    """One serial bus. Locked: FastAPI runs switch requests in a thread pool,
    so two taps at once must not interleave their frames on the wire."""

    def __init__(self, port: SerialPort, address: int) -> None:
        self._port = port
        self._address = address
        self._lock = threading.Lock()

    @classmethod
    def open(cls, device: str, baudrate: int, address: int) -> ModbusRtu:
        import serial  # pyserial, Pi-only extra

        return cls(serial.Serial(device, baudrate=baudrate, timeout=0.5), address)

    def _request(self, request: bytes, expected_len: int) -> bytes:
        with self._lock:
            last: Exception | None = None
            # One retry: a single garbled frame on a vehicle bus is not news.
            for _ in range(2):
                self._port.reset_input_buffer()
                self._port.write(request)
                reply = self._port.read(expected_len)
                try:
                    return self._check(request, reply, expected_len)
                except ModbusError as exc:
                    last = exc
            raise last  # type: ignore[misc]

    def _check(self, request: bytes, reply: bytes, expected_len: int) -> bytes:
        if len(reply) < 5:
            raise ModbusError("relay module did not answer")
        if reply[1] == request[1] | 0x80:
            raise ModbusError(f"relay module refused the request (code {reply[2]})")
        if len(reply) != expected_len or reply[:2] != request[:2]:
            raise ModbusError("unexpected answer from relay module")
        if crc16(reply[:-2]) != reply[-2:]:
            raise ModbusError("checksum error on the RS485 line")
        return reply

    def write_coil(self, index: int, on: bool) -> None:
        request = frame(self._address, WRITE_SINGLE_COIL, index, COIL_ON if on else COIL_OFF)
        # The module echoes a successful write back byte for byte.
        if self._request(request, len(request)) != request:
            raise ModbusError("relay module did not confirm the switch")

    def write_register(self, register: int, value: int) -> None:
        request = frame(self._address, WRITE_REGISTER, register, value)
        if self._request(request, len(request)) != request:
            raise ModbusError("relay module did not confirm the setting")

    def read_coil(self, index: int) -> bool:
        reply = self._request(frame(self._address, READ_COILS, index, 1), 6)
        return bool(reply[3] & 1)


class ModbusOutput(Output):
    """One relay of the module. Channel 1-8 as printed on the case.

    With `button`, the input of the same number toggles the relay inside the
    module, so a pushbutton works even while the Pi is down. The module's
    state is then the truth, and `read` is how the controller learns of it.
    """

    def __init__(self, bus: ModbusRtu, channel: int, button: bool = False) -> None:
        self._bus = bus
        self._index = channel - 1
        # Set on every start, either way: whether the module keeps the mode
        # across power cycles is undocumented, and a removed button must not
        # stay active.
        self._bus.write_register(
            INPUT_MODE_BASE + self._index, MODE_TOGGLE if button else MODE_COMMAND_ONLY
        )
        # Same rule as GPIO: everything starts off.
        self._bus.write_coil(self._index, False)

    def set(self, on: bool) -> None:
        self._bus.write_coil(self._index, on)

    def read(self) -> bool | None:
        return self._bus.read_coil(self._index)
