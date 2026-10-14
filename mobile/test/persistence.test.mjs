import assert from 'node:assert/strict'
import test from 'node:test'
import { createExpenseStorage } from '../src/persistence.js'

const row = (id) => ({ id, description: 'Lunch', amount: 5, category: 'Food', date: '2026-01-01' })
function fixture(raw = null) {
  const changes = []
  let value = raw
  const adapter = { getItem: async () => value, setItem: async (_, next) => { value = next } }
  const store = createExpenseStorage(adapter, (rows) => changes.push(rows))
  return { store, adapter, changes, disk: () => value }
}

test('does not publish a save until persistence succeeds', async () => {
  const f = fixture()
  await f.store.load()
  let finish
  f.adapter.setItem = () => new Promise((resolve) => { finish = resolve })
  const pending = f.store.commit((rows) => [row('1'), ...rows])
  await Promise.resolve()
  assert.deepEqual(f.changes, [[]])
  finish()
  await pending
  assert.deepEqual(f.changes.at(-1), [row('1')])
})

test('failed add, edit, and delete retain saved state and allow retries', async () => {
  for (const transform of [
    (rows) => [row('2'), ...rows],
    (rows) => rows.map((e) => ({ ...e, amount: 9 })),
    () => [],
  ]) {
    const f = fixture(JSON.stringify([row('1')]))
    await f.store.load()
    const write = f.adapter.setItem
    f.adapter.setItem = async () => { throw new Error('Disk unavailable') }
    await assert.rejects(f.store.commit(transform), /Disk unavailable/)
    assert.deepEqual(f.changes, [[row('1')]])
    assert.deepEqual(JSON.parse(f.disk()), [row('1')])
    f.adapter.setItem = write
    await f.store.commit(transform)
    assert.deepEqual(JSON.parse(f.disk()), transform([row('1')]))
  }
})

test('concurrent saves and refresh are serialized without lost expenses', async () => {
  const f = fixture()
  await f.store.load()
  await Promise.all([
    f.store.commit((rows) => [row('1'), ...rows]),
    f.store.commit((rows) => [row('2'), ...rows]),
    f.store.load(),
  ])
  assert.deepEqual(f.changes.at(-1), [row('2'), row('1')])
  assert.deepEqual(JSON.parse(f.disk()), f.changes.at(-1))
})

test('unreadable storage cannot be overwritten by an empty session', async () => {
  for (const raw of ['', '{invalid', '{}', 'null', '[{}]']) {
    const f = fixture(raw)
    await assert.rejects(f.store.load())
    await assert.rejects(f.store.commit(() => [row('1')]), /Load existing expenses/)
    assert.equal(f.disk(), raw)
    assert.deepEqual(f.changes, [])
  }
})

test('failed initial read can be retried without losing existing data', async () => {
  const f = fixture(JSON.stringify([row('1')]))
  const read = f.adapter.getItem
  f.adapter.getItem = async () => { throw new Error('Read failed') }
  await assert.rejects(f.store.load(), /Read failed/)
  await assert.rejects(f.store.commit(() => []))
  f.adapter.getItem = read
  await f.store.load()
  assert.deepEqual(f.changes.at(-1), [row('1')])
})

test('failed refresh retains the previously loaded state', async () => {
  const f = fixture(JSON.stringify([row('1')]))
  await f.store.load()
  f.adapter.getItem = async () => { throw new Error('Read failed') }
  await assert.rejects(f.store.load(), /Read failed/)
  assert.deepEqual(f.changes, [[row('1')]])
})
