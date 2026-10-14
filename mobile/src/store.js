import AsyncStorage from '@react-native-async-storage/async-storage'
import { useCallback, useEffect, useState } from 'react'
import { createExpenseStorage } from './persistence'

/** Keep the last saved state visible until an operation successfully persists. */
export function useExpenses() {
  const [expenses, setExpenses] = useState([])
  const [ready, setReady] = useState(false)
  const [loadError, setLoadError] = useState(false)
  const [storage] = useState(() => createExpenseStorage(AsyncStorage, setExpenses))

  const initialize = useCallback(() => storage.load()
    .then(() => setLoadError(false), () => setLoadError(true))
    .finally(() => setReady(true)), [storage])

  useEffect(() => { initialize() }, [initialize])
  const retry = useCallback(() => {
    setReady(false)
    return initialize()
  }, [initialize])

  const add = useCallback((e) => {
    const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    return storage.commit((rows) => [{ ...e, id }, ...rows])
  }, [storage])
  const addMany = useCallback((list) => {
    const base = Date.now()
    return storage.commit((rows) => [...list.map((e, i) => ({ ...e, id: `${base.toString(36)}-${i}` })), ...rows])
  }, [storage])
  const reload = useCallback(() => storage.load(), [storage])
  const update = useCallback((id, e) => storage.commit((rows) => rows.map((r) => (r.id === id ? { ...e, id } : r))), [storage])
  const remove = useCallback((id) => storage.commit((rows) => rows.filter((r) => r.id !== id)), [storage])

  return { expenses, ready, loadError, retry, add, addMany, update, remove, reload }
}
