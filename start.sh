#!/usr/bin/env bash
# Runs the FastAPI backend (:8000) and the Vite dev server (:5173).
set -e
cd "$(dirname "$0")"
[ -d backend/.venv ] || { python3 -m venv backend/.venv && backend/.venv/bin/pip install -q -r backend/requirements.txt; }
[ -d frontend/node_modules ] || (cd frontend && npm install)
trap 'kill 0' EXIT
(cd backend && .venv/bin/uvicorn main:app --port 8000) &
(cd frontend && npm run dev -- --port 5173) &
wait
