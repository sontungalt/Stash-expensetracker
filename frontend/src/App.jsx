import { useCallback, useEffect, useMemo, useState } from 'react'
import { connect } from './api.js'
import { CategoryPie, MonthlyBar } from './Charts.jsx'
import ExpenseForm from './ExpenseForm.jsx'
import TransactionTable from './TransactionTable.jsx'
import { categoryTotals, money, monthKey, monthLabel, monthlyTotals, sampleExpenses, shiftMonth, todayISO } from './lib.js'

export default function App() {
  const [api, setApi] = useState(null)
  const [expenses, setExpenses] = useState([])
  const [loadError, setLoadError] = useState('')
  const [selected, setSelected] = useState('all') // 'all' | 'YYYY-MM'
  const [editing, setEditing] = useState(null)
  const [toast, setToast] = useState('')

  const refresh = useCallback(async (a) => setExpenses(await a.list()), [])

  useEffect(() => {
    connect()
      .then(async (a) => {
        setApi(a)
        await refresh(a)
      })
      .catch((e) => setLoadError(e.message))
  }, [refresh])

  const flash = (msg) => {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  async function save(data) {
    if (editing) {
      await api.update(editing.id, data)
      setEditing(null)
      flash('Expense updated')
    } else {
      await api.create(data)
      flash('Expense added')
    }
    await refresh(api)
  }

  async function remove(r) {
    if (!window.confirm(`Delete "${r.description}" (${money(r.amount)})?`)) return
    await api.remove(r.id)
    if (editing?.id === r.id) setEditing(null)
    await refresh(api)
    flash('Expense deleted')
  }

  async function loadSample() {
    for (const e of sampleExpenses()) await api.create(e)
    await refresh(api)
  }

  const nowKey = todayISO().slice(0, 7)
  const latestKey = useMemo(() => expenses.reduce((m, e) => (monthKey(e.date) > m ? monthKey(e.date) : m), nowKey), [expenses, nowKey])
  const monthly = useMemo(() => monthlyTotals(expenses, latestKey, 12), [expenses, latestKey])
  const scoped = useMemo(() => (selected === 'all' ? expenses : expenses.filter((e) => monthKey(e.date) === selected)), [expenses, selected])
  const cats = useMemo(() => categoryTotals(scoped), [scoped])

  const total = scoped.reduce((s, e) => s + e.amount, 0)
  const periodLabel = selected === 'all' ? 'All time' : monthLabel(selected, { month: 'long', year: 'numeric' })
  const prevTotal = selected === 'all' ? null : expenses.filter((e) => monthKey(e.date) === shiftMonth(selected, -1)).reduce((s, e) => s + e.amount, 0)
  const delta = prevTotal ? ((total - prevTotal) / prevTotal) * 100 : null
  const months = new Set(expenses.map((e) => monthKey(e.date))).size
  const avgMonth = months ? expenses.reduce((s, e) => s + e.amount, 0) / months : 0

  const monthOptions = useMemo(() => [...new Set(expenses.map((e) => monthKey(e.date)))].sort().reverse(), [expenses])

  if (loadError) return <main className="wrap"><p className="error">Couldn’t load expenses: {loadError}</p></main>
  if (!api) return <main className="wrap"><p className="empty">Loading…</p></main>

  return (
    <main className="wrap">
      <header className="top">
        <div>
          <h1>Expense Tracker</h1>
          <p className="sub">{api.mode === 'server' ? 'Synced with FastAPI backend' : 'Backend offline — saving in this browser'}</p>
        </div>
        <label className="period">
          <span>Period</span>
          <select value={selected} onChange={(e) => setSelected(e.target.value)}>
            <option value="all">All time</option>
            {monthOptions.map((k) => <option key={k} value={k}>{monthLabel(k, { month: 'long', year: 'numeric' })}</option>)}
          </select>
        </label>
      </header>

      {expenses.length === 0 && (
        <div className="card welcome">
          <p><strong>No expenses yet.</strong> Add your first one with the form, or explore the dashboard with sample data.</p>
          <button className="ghost" onClick={loadSample}>Load sample data</button>
        </div>
      )}

      <div className="stats">
        <div className="card stat"><small>Total spent · {periodLabel}</small><strong>{money(total)}</strong>
          {delta !== null && <em className={delta > 0 ? 'up' : 'down'}>{delta > 0 ? '▲' : '▼'} {Math.abs(delta).toFixed(0)}% vs previous month</em>}
        </div>
        <div className="card stat"><small>Transactions</small><strong>{scoped.length}</strong></div>
        <div className="card stat"><small>Top category</small><strong>{cats[0]?.name ?? '—'}</strong>{cats[0] && <em>{money(cats[0].value)}</em>}</div>
        <div className="card stat"><small>Average per month</small><strong>{money(avgMonth)}</strong><em>across {months} month{months === 1 ? '' : 's'}</em></div>
      </div>

      <div className="grid">
        <MonthlyBar data={monthly} selected={selected} onSelect={setSelected} />
        <CategoryPie data={cats} periodLabel={periodLabel} />
        <ExpenseForm editing={editing} onSubmit={save} onCancel={() => setEditing(null)} />
        <TransactionTable rows={scoped} onEdit={(r) => { setEditing(r); window.scrollTo({ top: 0, behavior: 'smooth' }) }} onDelete={remove} />
      </div>

      <div className={`toast ${toast ? 'show' : ''}`} role="status">{toast}</div>
    </main>
  )
}
