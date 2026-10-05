.PHONY: install dev test lint fmt app-build app-demo app-test

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

app-build:  ## Flutter-App für den Pi (verbindet sich mit der eigenen Adresse)
	cd app && flutter build web --release

app-demo:  ## Flutter-App im Demo-Modus, http://localhost:8091
	cd app && flutter build web --release --dart-define=DEMO=true
	cd app/build/web && python3 -m http.server 8091

app-test:
	cd app && flutter analyze && flutter test
