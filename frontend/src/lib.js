export const CATEGORIES = ['Food', 'Transport', 'Housing', 'Shopping', 'Entertainment', 'Health', 'Bills', 'Other']

// Fixed entity -> color slot (never reassigned by rank or filter). Slots defined in index.css.
export const catColor = (cat) => `var(--c${CATEGORIES.indexOf(cat) + 1})`

export const money = (n) =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n)

export const moneyShort = (n) =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', notation: 'compact', maximumFractionDigits: 1 }).format(n)

export const monthKey = (iso) => iso.slice(0, 7)

export const monthLabel = (key, opts = { month: 'short', year: '2-digit' }) => {
  const [y, m] = key.split('-').map(Number)
  return new Date(y, m - 1, 1).toLocaleDateString('en-US', opts)
}

export const todayISO = () => {
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export const shiftMonth = (key, delta) => {
  const [y, m] = key.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** Last `n` months ending at `endKey`, with zero-filled totals. */
export function monthlyTotals(expenses, endKey, n = 12) {
  const totals = {}
  for (const e of expenses) totals[monthKey(e.date)] = (totals[monthKey(e.date)] || 0) + e.amount
  return Array.from({ length: n }, (_, i) => {
    const key = shiftMonth(endKey, i - (n - 1))
    return { key, label: monthLabel(key), total: Math.round((totals[key] || 0) * 100) / 100 }
  })
}

export function categoryTotals(expenses) {
  const totals = {}
  for (const e of expenses) totals[e.category] = (totals[e.category] || 0) + e.amount
  return CATEGORIES.filter((c) => totals[c]).map((c) => ({ name: c, value: Math.round(totals[c] * 100) / 100 }))
    .sort((a, b) => b.value - a.value)
}

export function sampleExpenses() {
  const now = new Date()
  const rows = [
    ['Groceries', 84.3, 'Food', 2], ['Coffee', 4.5, 'Food', 1], ['Dinner out', 46, 'Food', 9],
    ['Metro card', 40, 'Transport', 3], ['Ride share', 18.75, 'Transport', 12],
    ['Rent', 1200, 'Housing', 1], ['Sneakers', 89.99, 'Shopping', 10], ['Movie night', 24, 'Entertainment', 6],
    ['Pharmacy', 15.2, 'Health', 14], ['Electricity', 62.4, 'Bills', 5], ['Internet', 45, 'Bills', 7],
    ['Gift', 30, 'Other', 18],
  ]
  const out = []
  for (let back = 0; back < 6; back++) {
    for (const [description, amount, category, day] of rows) {
      const d = new Date(now.getFullYear(), now.getMonth() - back, day)
      if (d > now) continue
      const jitter = 1 + (((back * 7 + day * 3) % 11) - 5) / 40
      out.push({
        description, category, date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
        amount: Math.round(amount * (category === 'Housing' ? 1 : jitter) * 100) / 100,
      })
    }
  }
  return out
}
