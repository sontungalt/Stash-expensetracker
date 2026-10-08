import os
import tempfile

os.environ["EXPENSE_DB"] = os.path.join(tempfile.mkdtemp(), "test.db")

from fastapi.testclient import TestClient  # noqa: E402

from main import app  # noqa: E402

client = TestClient(app)
sample = {"description": "Lunch", "amount": 12.5, "category": "Food", "date": "2026-10-01"}


def test_crud_roundtrip():
    r = client.post("/api/expenses", json=sample)
    assert r.status_code == 201
    eid = r.json()["id"]
    assert any(e["id"] == eid for e in client.get("/api/expenses").json())

    r = client.put(f"/api/expenses/{eid}", json={**sample, "amount": 20})
    assert r.json()["amount"] == 20

    assert client.delete(f"/api/expenses/{eid}").status_code == 204
    assert client.delete(f"/api/expenses/{eid}").status_code == 404


def test_validation():
    assert client.post("/api/expenses", json={**sample, "amount": -5}).status_code == 422
    assert client.post("/api/expenses", json={**sample, "category": "Nope"}).status_code == 422
    assert client.post("/api/expenses", json={**sample, "description": ""}).status_code == 422


def test_sorted_newest_first():
    client.post("/api/expenses", json={**sample, "date": "2025-01-01"})
    client.post("/api/expenses", json={**sample, "date": "2026-12-01"})
    dates = [e["date"] for e in client.get("/api/expenses").json()]
    assert dates == sorted(dates, reverse=True)
