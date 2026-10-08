import os
import sqlite3
from contextlib import contextmanager
from datetime import date
from typing import Literal, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

DB_PATH = os.environ.get("EXPENSE_DB", os.path.join(os.path.dirname(__file__), "expenses.db"))

Category = Literal["Food", "Transport", "Housing", "Shopping", "Entertainment", "Health", "Bills", "Other"]


class ExpenseIn(BaseModel):
    description: str = Field(min_length=1, max_length=120)
    amount: float = Field(gt=0, lt=1_000_000_000)
    category: Category
    date: date


class Expense(ExpenseIn):
    id: int


@contextmanager
def db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with db() as c:
        c.execute(
            """CREATE TABLE IF NOT EXISTS expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                description TEXT NOT NULL,
                amount REAL NOT NULL,
                category TEXT NOT NULL,
                date TEXT NOT NULL
            )"""
        )


app = FastAPI(title="Expense Tracker")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
init_db()


def row_to_expense(r: sqlite3.Row) -> Expense:
    return Expense(id=r["id"], description=r["description"], amount=r["amount"], category=r["category"], date=r["date"])


@app.get("/api/expenses", response_model=list[Expense])
def list_expenses():
    with db() as c:
        rows = c.execute("SELECT * FROM expenses ORDER BY date DESC, id DESC").fetchall()
    return [row_to_expense(r) for r in rows]


@app.post("/api/expenses", response_model=Expense, status_code=201)
def create_expense(e: ExpenseIn):
    with db() as c:
        cur = c.execute(
            "INSERT INTO expenses (description, amount, category, date) VALUES (?, ?, ?, ?)",
            (e.description.strip(), round(e.amount, 2), e.category, e.date.isoformat()),
        )
        row = c.execute("SELECT * FROM expenses WHERE id = ?", (cur.lastrowid,)).fetchone()
    return row_to_expense(row)


@app.put("/api/expenses/{expense_id}", response_model=Expense)
def update_expense(expense_id: int, e: ExpenseIn):
    with db() as c:
        cur = c.execute(
            "UPDATE expenses SET description=?, amount=?, category=?, date=? WHERE id=?",
            (e.description.strip(), round(e.amount, 2), e.category, e.date.isoformat(), expense_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(404, "Expense not found")
        row = c.execute("SELECT * FROM expenses WHERE id = ?", (expense_id,)).fetchone()
    return row_to_expense(row)


@app.delete("/api/expenses/{expense_id}", status_code=204)
def delete_expense(expense_id: int):
    with db() as c:
        cur = c.execute("DELETE FROM expenses WHERE id = ?", (expense_id,))
        if cur.rowcount == 0:
            raise HTTPException(404, "Expense not found")
