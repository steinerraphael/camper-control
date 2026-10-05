"""Entry point: `camper-control` or `python -m camper.main`."""

from __future__ import annotations

import logging
import os

import uvicorn

from .api import create_app
from .config import load_config


def run() -> None:
    logging.basicConfig(
        level=os.environ.get("CAMPER_LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    config = load_config()
    uvicorn.run(
        create_app(config),
        host=os.environ.get("CAMPER_HOST", "0.0.0.0"),
        port=int(os.environ.get("CAMPER_PORT", "8080")),
        log_level="warning",
    )


if __name__ == "__main__":
    run()
