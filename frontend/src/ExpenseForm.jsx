import { useEffect, useRef, useState } from 'react'
import { CATEGORIES, catColor, todayISO } from './lib.js'

const blank = () => ({ description: '', amount: '', category: 'Food', date: todayISO() })

export default function ExpenseForm({ editing, onSubmit, onCancel }) {
  const [form, setForm] = useState(blank)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const descRef = useRef(null)

  useEffect(() => {
    setForm(editing ? { ...editing, amount: String(editing.amount) } : blank())
    setError('')
    if (editing) descRef.current?.focus()
  }, [editing])

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }))

  async function submit(e) {
    e.preventDefault()
    const amount = parseFloat(form.amount)
    if (!form.description.trim()) return setError('Add a short description.')
    if (!(amount > 0)) return setError('Amount must be greater than zero.')
    if (!form.date) return setError('Pick a date.')
    setBusy(true)
    try {
      await onSubmit({ description: form.description.trim(), amount: Math.round(amount * 100) / 100, category: form.category, date: form.date })
      setForm((f) => ({ ...blank(), category: f.category, date: f.date }))
      setError('')
      if (!editing) descRef.current?.focus()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="card form" onSubmit={submit} noValidate>
      <h2>{editing ? 'Edit expense' : 'Add expense'}</h2>

      <label>
        <span>Description</span>
        <input ref={descRef} value={form.description} onChange={set('description')} placeholder="e.g. Lunch with Sam" maxLength={120} />
      </label>

      <div className="row2">
        <label>
          <span>Amount</span>
          <div className="money-input">
            <i>$</i>
            <input type="number" inputMode="decimal" step="0.01" min="0" value={form.amount} onChange={set('amount')} placeholder="0.00" />
          </div>
        </label>
        <label>
          <span>Date</span>
          <input type="date" value={form.date} max="2100-12-31" onChange={set('date')} />
        </label>
      </div>

      <fieldset>
        <legend>Category</legend>
        <div className="chips">
          {CATEGORIES.map((c) => (
            <label key={c} className={`chip ${form.category === c ? 'on' : ''}`}>
              <input type="radio" name="category" value={c} checked={form.category === c} onChange={set('category')} />
              <span className="dot" style={{ background: catColor(c) }} />
              {c}
            </label>
          ))}
        </div>
      </fieldset>

      {error && <p className="error" role="alert">{error}</p>}

      <div className="actions">
        <button className="primary" disabled={busy}>{editing ? 'Save changes' : 'Add expense'}</button>
        {editing && <button type="button" className="ghost" onClick={onCancel}>Cancel</button>}
      </div>
    </form>
  )
}
