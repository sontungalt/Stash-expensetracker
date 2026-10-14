const KEY = 'expense-tracker:v1'

/** Serialize reads/writes, publishing state only after a successful disk write. */
export function createExpenseStorage(storage, onChange) {
  let rows = []
  let loaded = false
  let queue = Promise.resolve()

  const enqueue = (operation) => {
    const result = queue.then(operation)
    // A failed operation must reach its caller without blocking later retries.
    queue = result.catch(() => {})
    return result
  }

  return {
    load: () => enqueue(async () => {
      const raw = await storage.getItem(KEY)
      const next = raw === null ? [] : JSON.parse(raw)
      if (!Array.isArray(next) || next.some((e) => !e || typeof e.id !== 'string' ||
        typeof e.description !== 'string' || typeof e.category !== 'string' ||
        typeof e.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(e.date) ||
        !Number.isFinite(e.amount) || e.amount <= 0 ||
        (e.kind !== undefined && e.kind !== 'income' && e.kind !== 'expense'))) {
        throw new Error('Stored expenses could not be read safely.')
      }
      rows = next
      loaded = true
      onChange(rows)
    }),
    commit: (transform) => enqueue(async () => {
      if (!loaded) throw new Error('Load existing expenses before making changes.')
      const next = transform(rows)
      await storage.setItem(KEY, JSON.stringify(next))
      rows = next
      onChange(rows)
    }),
  }
}
