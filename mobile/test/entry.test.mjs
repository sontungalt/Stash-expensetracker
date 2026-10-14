import assert from 'node:assert/strict'
import test from 'node:test'
import { parseAmount, recentExpenses, repeatExpense, todayISO } from '../src/lib.js'

const expense = (id, date, description = 'Coffee', amount = 4.5, category = 'Food') => ({ id, date, description, amount, category })

test('amounts accept decimal keyboards and preserve cents', () => {
  for (const [input, expected] of [['12', 12], ['12.', 12], ['12,50', 12.5], ['.01', 0.01], [',50', 0.5], [' 1.05 ', 1.05]]) {
    assert.equal(parseAmount(input), expected, input)
  }
})

test('amounts reject partial numbers, grouping, non-finite values, and sub-cent amounts', () => {
  for (const input of ['', '0', '-4.50', '12.3.4', '12,34,56', '1,000', '1,234.56', '12abc', '1e3', 'Infinity', 'NaN', '0.001', '4.567', '9'.repeat(400)]) {
    assert.equal(parseAmount(input), null, input)
  }
})

test('shortcuts use newest distinct description/category pairs without changing history', () => {
  const rows = [expense('old', '2026-01-01'), expense('new', '2026-02-01', ' coffee ', 6), expense('other', '2026-01-15', 'Coffee', 8, 'Other')]
  const snapshot = structuredClone(rows)
  assert.deepEqual(recentExpenses(rows).map((e) => e.id), ['new', 'other'])
  assert.deepEqual(recentExpenses(rows, 1).map((e) => e.id), ['new'])
  assert.deepEqual(rows, snapshot)
  assert.deepEqual(recentExpenses([]), [])
})

test('repeating an expense creates an editable draft dated today with no reused ID', () => {
  const source = expense('original', '2025-01-01')
  const draft = repeatExpense(source)
  assert.deepEqual(draft, { description: 'Coffee', amount: '4.5', category: 'Food', kind: 'expense', date: todayISO() })
  assert.equal(source.date, '2025-01-01')
})
