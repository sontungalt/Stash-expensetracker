export const CATEGORIES = ['Food', 'Transport', 'Housing', 'Shopping', 'Entertainment', 'Health', 'Bills', 'Other']
export const INCOME_CATEGORIES = ['Allowance', 'Salary', 'Gift', 'Refund']

/** Entries are expenses unless marked `kind: 'income'`, so data saved before income existed still works. */
export const isIncome = (e) => e.kind === 'income'

/** Accept a decimal point or comma, never partial numbers or grouping separators. */
export function parseAmount(value) {
  const text = String(value).trim()
  if (!/^(?:\d+(?:[.,]\d{0,2})?|[.,]\d{1,2})$/.test(text)) return null
  const [whole, fraction = ''] = text.replace(',', '.').split('.')
  const cents = Number(whole || '0') * 100 + Number(fraction.padEnd(2, '0'))
  return Number.isSafeInteger(cents) && cents > 0 ? cents / 100 : null
}

/** Most recent version of each description/category pair; never mutate history. */
export function recentExpenses(expenses, limit = 6) {
  const seen = new Set()
  return [...expenses].sort((a, b) => b.date.localeCompare(a.date)).filter((e) => {
    const key = JSON.stringify([isIncome(e), e.description.trim().toLowerCase(), e.category])
    if (seen.has(key)) return false
    seen.add(key)
    return true
  }).slice(0, limit)
}

export function repeatExpense(expense) {
  return { description: expense.description, amount: String(expense.amount), category: expense.category, kind: isIncome(expense) ? 'income' : 'expense', date: todayISO() }
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTHS_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

const group = (s) => s.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
export const money = (n) => `${n < 0 ? '-' : ''}$${group(Math.abs(n).toFixed(2))}`
export const moneyShort = (n) => (n >= 1000 ? `$${+(n / 1000).toFixed(1)}K` : `$${Math.round(n)}`)

const pad = (n) => String(n).padStart(2, '0')
export const toISO = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
export const fromISO = (iso) => {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}
export const todayISO = () => toISO(new Date())
export const monthKey = (iso) => iso.slice(0, 7)

export const monthLabel = (key, long = false) => {
  const [y, m] = key.split('-').map(Number)
  return long ? `${MONTHS_LONG[m - 1]} ${y}` : `${MONTHS[m - 1]} '${String(y).slice(2)}`
}
export const dayLabel = (iso) => {
  const [y, m, d] = iso.split('-').map(Number)
  return `${MONTHS[m - 1]} ${d}, ${y}`
}
export const shiftMonth = (key, delta) => {
  const [y, m] = key.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`
}

const r2 = (n) => Math.round(n * 100) / 100 + 0 // `+ 0` turns -0 into 0

/** Money in, money out, and what is left (negative when over). */
export function summarize(entries) {
  let income = 0, spent = 0
  for (const e of entries) {
    if (isIncome(e)) income += e.amount
    else spent += e.amount
  }
  return { income: r2(income), spent: r2(spent), net: r2(income - spent) }
}

/** Last `n` months ending at `endKey`, zero-filled; income is ignored. */
export function monthlyTotals(expenses, endKey, n = 6) {
  const totals = {}
  for (const e of expenses.filter((x) => !isIncome(x))) totals[monthKey(e.date)] = (totals[monthKey(e.date)] || 0) + e.amount
  return Array.from({ length: n }, (_, i) => {
    const key = shiftMonth(endKey, i - (n - 1))
    return { key, label: MONTHS[Number(key.slice(5)) - 1], total: r2(totals[key] || 0) }
  })
}

export function categoryTotals(expenses) {
  const totals = {}
  for (const e of expenses.filter((x) => !isIncome(x))) totals[e.category] = (totals[e.category] || 0) + e.amount
  return CATEGORIES.filter((c) => totals[c]).map((c) => ({ name: c, value: r2(totals[c]) })).sort((a, b) => b.value - a.value)
}

export function sampleExpenses() {
  const now = new Date()
  /** @type {Array<[string, number, string, number]>} */
  const rows = [
    ['Groceries', 84.3, 'Food', 2], ['Coffee', 4.5, 'Food', 1], ['Dinner out', 46, 'Food', 9],
    ['Metro card', 40, 'Transport', 3], ['Ride share', 18.75, 'Transport', 12],
    ['Rent', 1200, 'Housing', 1], ['Sneakers', 89.99, 'Shopping', 10], ['Movie night', 24, 'Entertainment', 6],
    ['Pharmacy', 15.2, 'Health', 14], ['Electricity', 62.4, 'Bills', 5], ['Internet', 45, 'Bills', 7], ['Gift', 30, 'Other', 18],
  ]
  const out = []
  for (let back = 0; back < 6; back++)
    for (const [description, amount, category, day] of rows) {
      const d = new Date(now.getFullYear(), now.getMonth() - back, day)
      if (d > now) continue
      const jitter = 1 + (((back * 7 + day * 3) % 11) - 5) / 40
      out.push({ description, category, date: toISO(d), amount: r2(amount * (category === 'Housing' ? 1 : jitter)) })
    }
  return out
}
