import { useMemo, useState } from 'react'
import { CATEGORIES, catColor, money } from './lib.js'

const PAGE = 15

export default function TransactionTable({ rows, onEdit, onDelete }) {
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('All')
  const [sort, setSort] = useState({ key: 'date', dir: 'desc' })
  const [page, setPage] = useState(0)

  const view = useMemo(() => {
    const needle = q.trim().toLowerCase()
    const f = rows.filter((r) => (cat === 'All' || r.category === cat) && (!needle || r.description.toLowerCase().includes(needle)))
    const m = sort.dir === 'asc' ? 1 : -1
    return f.sort((a, b) => {
      const x = a[sort.key], y = b[sort.key]
      const c = typeof x === 'number' ? x - y : String(x).localeCompare(String(y))
      return (c || b.id - a.id) * m
    })
  }, [rows, q, cat, sort])

  const pages = Math.max(1, Math.ceil(view.length / PAGE))
  const cur = Math.min(page, pages - 1)
  const slice = view.slice(cur * PAGE, cur * PAGE + PAGE)
  const sum = view.reduce((s, r) => s + r.amount, 0)

  const toggle = (key) => {
    setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: key === 'description' || key === 'category' ? 'asc' : 'desc' }))
    setPage(0)
  }
  const th = (key, label, cls = '') => (
    <th className={cls} aria-sort={sort.key === key ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}>
      <button className="th" onClick={() => toggle(key)}>{label}<i>{sort.key === key ? (sort.dir === 'asc' ? '▲' : '▼') : ''}</i></button>
    </th>
  )

  return (
    <section className="card">
      <div className="table-head">
        <div>
          <h2>Transactions</h2>
          <p className="sub">{view.length} shown · {money(sum)}</p>
        </div>
        <div className="filters">
          <input type="search" placeholder="Search description…" value={q} onChange={(e) => { setQ(e.target.value); setPage(0) }} aria-label="Search transactions" />
          <select value={cat} onChange={(e) => { setCat(e.target.value); setPage(0) }} aria-label="Filter by category">
            <option>All</option>
            {CATEGORIES.map((c) => <option key={c}>{c}</option>)}
          </select>
        </div>
      </div>

      {view.length === 0 ? (
        <p className="empty">No transactions match.</p>
      ) : (
        <div className="scroll">
          <table>
            <thead>
              <tr>{th('date', 'Date')}{th('description', 'Description')}{th('category', 'Category')}{th('amount', 'Amount', 'num')}<th aria-label="Actions" /></tr>
            </thead>
            <tbody>
              {slice.map((r) => (
                <tr key={r.id}>
                  <td className="nowrap">{new Date(r.date + 'T00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</td>
                  <td>{r.description}</td>
                  <td className="nowrap"><span className="dot" style={{ background: catColor(r.category) }} /> {r.category}</td>
                  <td className="num">{money(r.amount)}</td>
                  <td className="row-actions">
                    <button className="link" onClick={() => onEdit(r)} aria-label={`Edit ${r.description}`}>Edit</button>
                    <button className="link danger" onClick={() => onDelete(r)} aria-label={`Delete ${r.description}`}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {pages > 1 && (
        <div className="pager">
          <button className="ghost" disabled={cur === 0} onClick={() => setPage(cur - 1)}>← Prev</button>
          <span>Page {cur + 1} of {pages}</span>
          <button className="ghost" disabled={cur >= pages - 1} onClick={() => setPage(cur + 1)}>Next →</button>
        </div>
      )}
    </section>
  )
}
