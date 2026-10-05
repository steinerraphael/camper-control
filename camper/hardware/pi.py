"""Real hardware on the Raspberry Pi.

Imports of Pi-only packages happen inside the constructors, so this module
can be imported (and the rest of the app tested) on any machine.
"""

from __future__ import annotations

from pathlib import Path

from .base import Output, Sensor


class GpioOutput(Output):
    def __init__(self, pin: int, active_low: bool) -> None:
        from gpiozero import OutputDevice

        # initial_value=False: every channel starts OFF after a reboot or a
        # power dip. A pump that silently comes back on is worse than a light
        # that needs to be switched on again.
        self._dev = OutputDevice(pin, active_high=not active_low, initial_value=False)

    def set(self, on: bool) -> None:
        self._dev.value = on

    def close(self) -> None:
        self._dev.off()
        self._dev.close()


class Ina226(Sensor):
    """TI INA226 current/voltage monitor on I2C.

    Current is computed from the raw shunt voltage rather than through the
    chip's calibration register: one formula fewer to get wrong.
    """

    _REG_CONFIG = 0x00
    _REG_SHUNT = 0x01  # LSB 2.5 µV, signed
    _REG_BUS = 0x02  # LSB 1.25 mV
    # Continuous shunt + bus, 1.1 ms conversion, averaging over 16 samples.
    _CONFIG = 0x4527

    def __init__(self, bus: int, address: int, shunt_ohms: float) -> None:
        from smbus2 import SMBus

        self._bus = SMBus(bus)
        self._addr = address
        self._shunt_ohms = shunt_ohms
        self._bus.write_i2c_block_data(
            address, self._REG_CONFIG, [self._CONFIG >> 8, self._CONFIG & 0xFF]
        )

    def _word(self, reg: int) -> int:
        hi, lo = self._bus.read_i2c_block_data(self._addr, reg, 2)  # big-endian
        return (hi << 8) | lo

    def read(self) -> dict[str, float]:
        raw_shunt = self._word(self._REG_SHUNT)
        if raw_shunt & 0x8000:
            raw_shunt -= 1 << 16
        voltage = self._word(self._REG_BUS) * 1.25e-3
        current = raw_shunt * 2.5e-6 / self._shunt_ohms
        return {
            "voltage": round(voltage, 2),
            "current": round(current, 2),
            "power": round(voltage * current, 1),
        }

    def close(self) -> None:
        self._bus.close()


class Ds18b20(Sensor):
    """DS18B20 on the kernel's 1-Wire driver (dtoverlay=w1-gpio)."""

    def __init__(self, device_id: str) -> None:
        self._path = Path("/sys/bus/w1/devices") / device_id / "w1_slave"

    def read(self) -> dict[str, float]:
        lines = self._path.read_text().splitlines()
        # First line ends in YES when the CRC matched; otherwise the value is junk.
        if not lines or not lines[0].strip().endswith("YES"):
            raise OSError("1-Wire CRC check failed")
        _, _, milli = lines[1].partition("t=")
        return {"temperature": round(int(milli) / 1000, 1)}
