import assert from 'node:assert/strict'
import test from 'node:test'
import { INCOME_CATEGORIES, categoryTotals, monthlyTotals, recentExpenses, repeatExpense, summarize } from '../src/lib.js'
import { createExpenseStorage } from '../src/persistence.js'

const out = (id, amount, date = '2026-10-05', category = 'Food') => ({ id, description: 'Lunch', amount, category, date })
const inn = (id, amount, date = '2026-10-01', category = 'Allowance') => ({ id, description: 'Allowance', amount, category, date, kind: 'income' })

test('summarize splits money in from money out and reports the balance', () => {
  assert.deepEqual(summarize([out('a', 100), out('b', 41.6), inn('c', 100)]), { income: 100, spent: 141.6, net: -41.6 })
  assert.deepEqual(summarize([out('a', 10), inn('b', 25.5)]), { income: 25.5, spent: 10, net: 15.5 })
  assert.deepEqual(summarize([]), { income: 0, spent: 0, net: 0 })
})

test('summarize avoids floating point drift', () => {
  assert.equal(summarize([out('a', 0.1), out('b', 0.2), inn('c', 0.3)]).net, 0)
})

test('legacy entries without a kind count as spending', () => {
  assert.equal(summarize([out('a', 5)]).spent, 5)
})

test('spending charts ignore income', () => {
  const rows = [out('a', 20), inn('b', 500, '2026-10-01', 'Allowance')]
  assert.equal(monthlyTotals(rows, '2026-10', 1)[0].total, 20)
  assert.deepEqual(categoryTotals(rows), [{ name: 'Food', value: 20 }])
})

test('income categories include Allowance', () => {
  assert.ok(INCOME_CATEGORIES.includes('Allowance'))
})

test('repeating an entry keeps its kind', () => {
  assert.equal(repeatExpense(inn('a', 20)).kind, 'income')
  assert.equal(repeatExpense(out('a', 20)).kind, 'expense')
})

test('income and expense with the same description are distinct shortcuts', () => {
  const rows = [{ ...out('a', 5, '2026-10-02', 'Other'), description: 'Gift' }, { ...inn('b', 5, '2026-10-01', 'Other'), description: 'Gift' }]
  assert.equal(recentExpenses(rows).length, 2)
})

test('storage accepts income entries and rejects unknown kinds', async () => {
  const load = (rows) => createExpenseStorage({ getItem: async () => JSON.stringify(rows), setItem: async () => {} }, () => {}).load()
  await load([inn('a', 10), out('b', 5)])
  await assert.rejects(load([{ ...out('a', 5), kind: 'bogus' }]))
})
