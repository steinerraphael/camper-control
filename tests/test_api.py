from __future__ import annotations

from fastapi.testclient import TestClient

from camper.api import create_app


def test_state_and_switching(config, controller):
    with TestClient(create_app(config, controller)) as client:
        assert client.get("/health").json() == {"status": "ok", "driver": "mock"}

        state = client.get("/api/state").json()
        assert {s["id"] for s in state["switches"]} >= {"water_pump", "fridge"}

        res = client.put("/api/switches/fridge", json={"on": True})
        assert res.status_code == 200
        assert next(s for s in res.json()["switches"] if s["id"] == "fridge")["on"]


def test_unknown_switch_is_404(config, controller):
    with TestClient(create_app(config, controller)) as client:
        assert client.put("/api/switches/nope", json={"on": True}).status_code == 404


async def test_locked_switch_is_409(config, controller, battery, clock):
    battery.voltage_override = 11.0
    await controller.poll_once()
    clock.now = 60
    await controller.poll_once()
    battery.voltage_override = 11.0  # keep it low while the app polls on start
    with TestClient(create_app(config, controller)) as client:
        res = client.put("/api/switches/water_pump", json={"on": True})
        assert res.status_code == 409


def test_websocket_pushes_changes(config, controller):
    with (
        TestClient(create_app(config, controller)) as client,
        client.websocket_connect("/api/ws") as ws,
    ):
        ws.receive_json()  # initial snapshot
        client.put("/api/switches/reading_lights", json={"on": True})
        snap = ws.receive_json()
        assert next(s for s in snap["switches"] if s["id"] == "reading_lights")["on"]


def test_ui_is_served(config, controller):
    with TestClient(create_app(config, controller)) as client:
        res = client.get("/")
        assert res.status_code == 200
        assert "Camper" in res.text
