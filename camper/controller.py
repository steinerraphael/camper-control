"""The one place that owns switch state, sensor readings and protection.

The API and the UI only call into this; nothing else touches hardware.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import time
from dataclasses import dataclass, field
from typing import Any

from .config import Config
from .hardware import Output, Sensor

log = logging.getLogger(__name__)


class UnknownSwitch(KeyError):
    pass


class SwitchLocked(RuntimeError):
    """The switch was shed by low-voltage protection and stays off until recovery."""


class HardwareError(RuntimeError):
    """The relay could not be switched, e.g. the RS485 module did not answer."""


@dataclass
class SensorState:
    values: dict[str, float] = field(default_factory=dict)
    error: str | None = None
    updated_at: float | None = None


class Controller:
    def __init__(
        self,
        config: Config,
        outputs: dict[str, Output],
        sensors: dict[str, Sensor],
        clock: Any = time.monotonic,
    ) -> None:
        self.config = config
        self._outputs = outputs
        self._sensors = sensors
        self._clock = clock
        self._on: dict[str, bool] = {s.id: False for s in config.switches}
        self._sensor_state = {s.id: SensorState() for s in config.sensors}
        self._locked: set[str] = set()
        self._low_since: float | None = None
        self._protection_active = False
        self._subscribers: set[asyncio.Queue[dict[str, Any]]] = set()
        self._task: asyncio.Task[None] | None = None

    # -- switches ---------------------------------------------------------

    def set_switch(self, switch_id: str, on: bool) -> None:
        if switch_id not in self._outputs:
            raise UnknownSwitch(switch_id)
        if on and switch_id in self._locked:
            raise SwitchLocked(switch_id)
        try:
            self._outputs[switch_id].set(on)
        except OSError as exc:
            # State stays as it was: the app must not show a switch that did not happen.
            log.error("switch %s failed: %s", switch_id, exc)
            raise HardwareError(str(exc)) from exc
        self._on[switch_id] = on
        log.info("switch %s -> %s", switch_id, "on" if on else "off")
        self._publish()

    # -- sensors and protection ------------------------------------------

    async def poll_once(self) -> None:
        for sensor_id, sensor in self._sensors.items():
            state = self._sensor_state[sensor_id]
            try:
                state.values = await asyncio.to_thread(sensor.read)
                state.error = None
                state.updated_at = time.time()
            except Exception as exc:  # a flaky sensor must not stop the loop
                state.error = str(exc) or type(exc).__name__
                log.warning("sensor %s failed: %s", sensor_id, state.error)
        self._check_protection()
        self._publish()

    def _check_protection(self) -> None:
        p = self.config.protection
        if p is None:
            return
        battery = self._sensor_state[p.battery_sensor]
        voltage = battery.values.get("voltage")
        if voltage is None or battery.error:
            # No reading is no evidence of a flat battery. Hold the current state.
            return

        now = self._clock()
        if not self._protection_active:
            if voltage < p.cutoff_v:
                self._low_since = self._low_since if self._low_since is not None else now
                if now - self._low_since >= p.cutoff_delay_s:
                    self._shed(voltage)
            else:
                self._low_since = None
        elif voltage >= p.recover_v:
            # Unlock, but do not switch anything back on: the traveller decides.
            log.warning("battery recovered at %.2f V, loads unlocked", voltage)
            self._protection_active = False
            self._locked.clear()
            self._low_since = None

    def _shed(self, voltage: float) -> None:
        self._protection_active = True
        sheddable = sorted(
            (s for s in self.config.switches if s.shed_priority is not None),
            key=lambda s: s.shed_priority,  # type: ignore[arg-type, return-value]
        )
        for s in sheddable:
            self._outputs[s.id].set(False)
            self._on[s.id] = False
            self._locked.add(s.id)
        log.warning(
            "battery at %.2f V: shed %s", voltage, ", ".join(s.id for s in sheddable) or "nothing"
        )

    # -- state and push ---------------------------------------------------

    def snapshot(self) -> dict[str, Any]:
        return {
            "switches": [
                {
                    "id": s.id,
                    "name": s.name,
                    "on": self._on[s.id],
                    "locked": s.id in self._locked,
                    "load_a": s.load_a,
                }
                for s in self.config.switches
            ],
            "sensors": [
                {
                    "id": s.id,
                    "name": s.name,
                    "type": s.type,
                    "values": self._sensor_state[s.id].values,
                    "error": self._sensor_state[s.id].error,
                    "updated_at": self._sensor_state[s.id].updated_at,
                    "capacity_ah": getattr(s, "capacity_ah", None),
                }
                for s in self.config.sensors
            ],
            "protection": {
                "enabled": self.config.protection is not None,
                "active": self._protection_active,
                "cutoff_v": self.config.protection.cutoff_v if self.config.protection else None,
                "recover_v": self.config.protection.recover_v if self.config.protection else None,
            },
        }

    def subscribe(self) -> asyncio.Queue[dict[str, Any]]:
        q: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=8)
        self._subscribers.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue[dict[str, Any]]) -> None:
        self._subscribers.discard(q)

    def _publish(self) -> None:
        snap = self.snapshot()
        for q in self._subscribers:
            if q.full():  # a slow client gets the newest state, not a backlog
                q.get_nowait()
            q.put_nowait(snap)

    # -- lifecycle --------------------------------------------------------

    async def start(self) -> None:
        await self.poll_once()
        self._task = asyncio.create_task(self._loop())

    async def _loop(self) -> None:
        while True:
            await asyncio.sleep(self.config.poll_interval_s)
            await self.poll_once()

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._task
        for out in self._outputs.values():
            out.close()
        for sensor in self._sensors.values():
            sensor.close()
