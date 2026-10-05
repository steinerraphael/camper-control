"""Hardware interfaces. The controller only ever sees these."""

from __future__ import annotations

from abc import ABC, abstractmethod


class Output(ABC):
    """One switched channel: a relay or a MOSFET on a GPIO pin."""

    @abstractmethod
    def set(self, on: bool) -> None: ...

    def read(self) -> bool | None:
        """The actual state, when the hardware can be switched by other means
        (a pushbutton on a relay module). None: only this program switches it."""
        return None

    def close(self) -> None:  # noqa: B027 - optional hook
        pass


class Sensor(ABC):
    """Reads one device and returns named values, e.g. {"voltage": 12.7}.

    Reads are blocking (I2C, 1-Wire) and are run in a worker thread.
    """

    @abstractmethod
    def read(self) -> dict[str, float]: ...

    def close(self) -> None:  # noqa: B027 - optional hook
        pass
