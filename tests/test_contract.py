"""The app parses what the controller sends. This keeps the two from drifting.

The Flutter tests read app/test/fixtures/state.json. This test fails when the
controller's snapshot no longer has the shape of that fixture; regenerate it
with `UPDATE_FIXTURE=1 pytest tests/test_contract.py` and let the Flutter
tests tell you whether the app still copes.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

FIXTURE = Path(__file__).resolve().parent.parent / "app" / "test" / "fixtures" / "state.json"


def _shape(value: Any) -> Any:
    """Keys and types, not values: readings differ on every poll."""
    if isinstance(value, dict):
        return {k: _shape(v) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return [_shape(v) for v in value]
    if isinstance(value, bool) or value is None:
        return type(value).__name__
    if isinstance(value, int | float):
        return "number"
    return type(value).__name__


async def test_app_fixture_matches_snapshot(controller, battery):
    battery.voltage_override = 12.72
    controller.set_switch("water_pump", True)
    await controller.poll_once()
    snapshot = controller.snapshot()
    for s in snapshot["sensors"]:
        s["updated_at"] = 1_760_000_000.0  # stable fixture

    if os.environ.get("UPDATE_FIXTURE"):
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n")

    fixture = json.loads(FIXTURE.read_text())
    assert _shape(fixture) == _shape(snapshot), (
        "controller output changed shape; regenerate with UPDATE_FIXTURE=1"
    )
