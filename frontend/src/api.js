// Data layer: FastAPI backend when reachable, otherwise localStorage (same interface).
const LS_KEY = 'expense-tracker:v1'

const readLocal = () => {
  try {
    return JSON.parse(localStorage.getItem(LS_KEY)) || []
  } catch {
    return []
  }
}
const writeLocal = (rows) => {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(rows))
  } catch {
    /* storage blocked: data lives for this session only */
  }
}

const local = {
  mode: 'local',
  async list() {
    return readLocal().sort((a, b) => b.date.localeCompare(a.date) || b.id - a.id)
  },
  async create(e) {
    const rows = readLocal()
    const row = { ...e, id: Math.max(0, ...rows.map((r) => r.id)) + 1 }
    writeLocal([...rows, row])
    return row
  },
  async update(id, e) {
    writeLocal(readLocal().map((r) => (r.id === id ? { ...e, id } : r)))
  },
  async remove(id) {
    writeLocal(readLocal().filter((r) => r.id !== id))
  },
}

const json = async (res) => {
  if (!res.ok) throw new Error(`Request failed (${res.status})`)
  return res.status === 204 ? null : res.json()
}
const send = (method, url, body) =>
  fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: body && JSON.stringify(body) }).then(json)

const remote = {
  mode: 'server',
  list: () => fetch('/api/expenses').then(json),
  create: (e) => send('POST', '/api/expenses', e),
  update: (id, e) => send('PUT', `/api/expenses/${id}`, e),
  remove: (id) => send('DELETE', `/api/expenses/${id}`),
}

export async function connect() {
  try {
    const res = await fetch('/api/expenses', { signal: AbortSignal.timeout(2500) })
    if ((res.headers.get('content-type') || '').includes('json') && res.ok) return remote
  } catch {
    /* fall through */
  }
  return local
}
