.PHONY: install dev test lint fmt

install:
	uv venv -q --allow-existing .venv
	uv pip install -q -p .venv -e ".[dev]"

dev:  ## Mock-Hardware, http://localhost:8080
	.venv/bin/camper-control

test:
	.venv/bin/pytest -q

lint:
	.venv/bin/ruff check .
	.venv/bin/ruff format --check .

fmt:
	.venv/bin/ruff format .
	.venv/bin/ruff check --fix .
