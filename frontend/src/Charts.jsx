import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { catColor, money, moneyShort, monthLabel } from './lib.js'

function Tip({ active, payload, title }) {
  if (!active || !payload?.length) return null
  const p = payload[0]
  return (
    <div className="tip">
      <strong>{title(p)}</strong>
      <span>{money(p.value)}</span>
    </div>
  )
}

export function CategoryPie({ data, periodLabel }) {
  const total = data.reduce((s, d) => s + d.value, 0)
  return (
    <section className="card">
      <h2>Spending by category</h2>
      <p className="sub">{periodLabel}</p>
      {data.length === 0 ? (
        <p className="empty">No expenses in this period.</p>
      ) : (
        <div className="pie-wrap">
          <div className="pie" role="img" aria-label={`Donut chart of spending by category. ${data.map((d) => `${d.name} ${money(d.value)}`).join(', ')}`}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={data} dataKey="value" nameKey="name" innerRadius="58%" outerRadius="92%" stroke="var(--surface)" strokeWidth={2} isAnimationActive={false}>
                  {data.map((d) => <Cell key={d.name} fill={catColor(d.name)} />)}
                </Pie>
                <Tooltip content={<Tip title={(p) => p.name} />} />
              </PieChart>
            </ResponsiveContainer>
            <div className="pie-center"><small>Total</small><strong>{money(total)}</strong></div>
          </div>
          <ul className="legend">
            {data.map((d) => (
              <li key={d.name}>
                <span className="dot" style={{ background: catColor(d.name) }} />
                <span className="name">{d.name}</span>
                <span className="amt">{money(d.value)}</span>
                <span className="pct">{Math.round((d.value / total) * 100)}%</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  )
}

export function MonthlyBar({ data, selected, onSelect }) {
  const has = data.some((d) => d.total > 0)
  return (
    <section className="card">
      <h2>Monthly spending</h2>
      <p className="sub">Last 12 months · click a bar to focus that month</p>
      {!has ? (
        <p className="empty">No expenses in the last 12 months.</p>
      ) : (
        <div className="bar" role="img" aria-label={`Bar chart of monthly spending. ${data.map((d) => `${d.label} ${money(d.total)}`).join(', ')}`}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 8, right: 4, left: 0, bottom: 0 }}>
              <CartesianGrid vertical={false} stroke="var(--grid)" />
              <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fill: 'var(--text-2)', fontSize: 12 }} interval="preserveStartEnd" minTickGap={4} />
              <YAxis tickLine={false} axisLine={false} width={52} tick={{ fill: 'var(--text-2)', fontSize: 12 }} tickFormatter={moneyShort} />
              <Tooltip cursor={{ fill: 'var(--hover)' }} content={<Tip title={(p) => monthLabel(p.payload.key, { month: 'long', year: 'numeric' })} />} />
              <Bar dataKey="total" radius={[4, 4, 0, 0]} maxBarSize={36} isAnimationActive={false} onClick={(d) => onSelect(d.key === selected ? 'all' : d.key)} cursor="pointer">
                {data.map((d) => (
                  <Cell key={d.key} fill="var(--c1)" fillOpacity={selected === 'all' || selected === d.key ? 1 : 0.35} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </section>
  )
}
