import AsyncStorage from '@react-native-async-storage/async-storage'
import { useCallback, useEffect, useRef, useState } from 'react'

const KEY = 'expense-tracker:v1'

/** Expenses persisted on-device. All writes go through `commit` so state and storage never diverge. */
export function useExpenses() {
  const [expenses, setExpenses] = useState([])
  const [ready, setReady] = useState(false)
  const ref = useRef([])

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((raw) => {
        ref.current = raw ? JSON.parse(raw) : []
        setExpenses(ref.current)
      })
      .catch(() => {})
      .finally(() => setReady(true))
  }, [])

  const commit = useCallback((rows) => {
    ref.current = rows
    setExpenses(rows)
    AsyncStorage.setItem(KEY, JSON.stringify(rows)).catch(() => {})
  }, [])

  const add = useCallback((e) => {
    const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    commit([{ ...e, id }, ...ref.current])
  }, [commit])
  const addMany = useCallback((list) => {
    const base = Date.now()
    commit([...list.map((e, i) => ({ ...e, id: `${base.toString(36)}-${i}` })), ...ref.current])
  }, [commit])
  const reload = useCallback(async () => {
    const raw = await AsyncStorage.getItem(KEY)
    ref.current = raw ? JSON.parse(raw) : []
    setExpenses(ref.current)
  }, [])
  const update = useCallback((id, e) => commit(ref.current.map((r) => (r.id === id ? { ...e, id } : r))), [commit])
  const remove = useCallback((id) => commit(ref.current.filter((r) => r.id !== id)), [commit])

  return { expenses, ready, add, addMany, update, remove, reload }
}
