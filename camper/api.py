"""HTTP and WebSocket API, plus the web UI. Thin: everything real is in Controller."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from pydantic import BaseModel

from .config import Config
from .controller import Controller, SwitchLocked, UnknownSwitch
from .hardware import build_hardware

WEB_DIR = Path(__file__).resolve().parent / "web"


class SwitchRequest(BaseModel):
    on: bool


def create_app(config: Config, controller: Controller | None = None) -> FastAPI:
    if controller is None:
        outputs, sensors = build_hardware(config)
        controller = Controller(config, outputs, sensors)
    ctl = controller

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        await ctl.start()
        try:
            yield
        finally:
            await ctl.stop()

    app = FastAPI(title="Camper Control", lifespan=lifespan)
    app.state.controller = ctl

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "driver": config.driver}

    @app.get("/api/state")
    def state() -> dict[str, Any]:
        return ctl.snapshot()

    @app.put("/api/switches/{switch_id}")
    def set_switch(switch_id: str, body: SwitchRequest) -> dict[str, Any]:
        try:
            ctl.set_switch(switch_id, body.on)
        except UnknownSwitch:
            raise HTTPException(404, "unknown switch") from None
        except SwitchLocked:
            raise HTTPException(
                409, "switched off by low-voltage protection until the battery recovers"
            ) from None
        return ctl.snapshot()

    @app.websocket("/api/ws")
    async def ws(socket: WebSocket) -> None:
        await socket.accept()
        q = ctl.subscribe()
        try:
            await socket.send_json(ctl.snapshot())
            while True:
                await socket.send_json(await q.get())
        except WebSocketDisconnect:
            pass
        finally:
            ctl.unsubscribe(q)

    @app.get("/", include_in_schema=False)
    def index() -> FileResponse:
        return FileResponse(WEB_DIR / "index.html")

    @app.get("/manifest.webmanifest", include_in_schema=False)
    def manifest() -> FileResponse:
        return FileResponse(
            WEB_DIR / "manifest.webmanifest", media_type="application/manifest+json"
        )

    return app
