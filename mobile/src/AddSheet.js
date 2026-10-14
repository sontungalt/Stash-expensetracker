import DateTimePicker from '@react-native-community/datetimepicker'
import { LinearGradient } from 'expo-linear-gradient'
import { useEffect, useRef, useState } from 'react'
import { Keyboard, Modal, Platform, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native'
import * as Haptics from 'expo-haptics'
import { Glass, Backdrop } from './Glass'
import { FadeIn, PopPressable, useReducedMotion } from './hooks'
import { CATEGORIES, INCOME_CATEGORIES, fromISO, isIncome, money, parseAmount, repeatExpense, toISO } from './lib'
import { alpha, ICONS, rounded, useTheme } from './theme'

const blank = () => ({ description: '', amount: '', category: 'Food', kind: 'expense', date: toISO(new Date()) })
function useKeyboardHeight() {
  const [h, setH] = useState(0)
  useEffect(() => {
    const show = Keyboard.addListener(Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow', (e) => setH(e.endCoordinates.height))
    const hide = Keyboard.addListener(Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide', () => setH(0))
    return () => { show.remove(); hide.remove() }
  }, [])
  return h
}

const buzz = (type) => Haptics.notificationAsync(type).catch(() => {})

export default function AddSheet({ visible, editing, recent = [], onClose, onSave, onDelete }) {
  const t = useTheme()
  const reduced = useReducedMotion()
  return (
    <Modal visible={visible} animationType={reduced ? 'none' : 'slide'} presentationStyle="pageSheet" onRequestClose={onClose}>
      {/* Form remounts per open, so its state always starts fresh (or from the expense being edited). */}
      {visible && <Form key={editing?.id ?? 'new'} t={t} editing={editing} recent={recent} onClose={onClose} onSave={onSave} onDelete={onDelete} />}
    </Modal>
  )
}

function Form({ t, editing, recent, onClose, onSave, onDelete }) {
  const [f, setF] = useState(() => (editing ? { ...editing, amount: String(editing.amount), kind: isIncome(editing) ? 'income' : 'expense' } : blank()))
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const submitting = useRef(false)
  const kb = useKeyboardHeight()

  const income = f.kind === 'income'
  const categories = income ? INCOME_CATEGORIES : CATEGORIES
  const set = (k, v) => setF((x) => ({ ...x, [k]: v }))
  const setKind = (kind) => {
    if (kind === f.kind) return
    Haptics.selectionAsync().catch(() => {})
    setF((x) => ({ ...x, kind, category: kind === 'income' ? INCOME_CATEGORIES[0] : CATEGORIES[0] }))
  }
  const fail = (m) => { setError(m); buzz(Haptics.NotificationFeedbackType.Error) }

  async function submit() {
    if (submitting.current) return
    const amount = parseAmount(f.amount)
    if (amount === null) return fail('Enter a positive amount with no more than two decimal places.')
    if (!f.description.trim()) return fail('Add a short description.')
    submitting.current = true
    setSaving(true)
    setError('')
    try {
      await onSave({ description: f.description.trim(), amount, category: f.category, kind: f.kind, date: f.date })
      buzz(Haptics.NotificationFeedbackType.Success)
      onClose()
    } catch {
      fail(`Could not save your ${income ? 'income' : 'expense'}. Your entries are still here—please try again.`)
    } finally {
      submitting.current = false
      setSaving(false)
    }
  }

  const accent = t.cat(f.category)

  return (
      <View style={{ flex: 1, paddingBottom: kb }}>
        <Backdrop />
        <View style={styles.header}>
          <PopPressable onPress={onClose} disabled={saving} hitSlop={12} accessibilityRole="button"><Text style={{ color: t.text2, fontSize: 17 }}>Cancel</Text></PopPressable>
          <Text style={{ color: t.text, fontSize: 17, fontWeight: '700' }}>{editing ? (income ? 'Edit Income' : 'Edit Expense') : (income ? 'New Income' : 'New Expense')}</Text>
          <View style={{ width: 52 }} />
        </View>

        <ScrollView contentContainerStyle={{ padding: 16, gap: 20, paddingBottom: 24 }} keyboardShouldPersistTaps="handled" keyboardDismissMode="interactive">
          <View style={[styles.kinds, { backgroundColor: t.chip, borderColor: t.glassEdge }]} accessibilityRole="radiogroup">
            {[['expense', 'Expense'], ['income', 'Income']].map(([k, label]) => {
              const on = f.kind === k
              return (
                <PopPressable key={k} disabled={saving} onPress={() => setKind(k)} accessibilityRole="radio" accessibilityState={{ selected: on }}
                  style={[styles.kind, on && { backgroundColor: k === 'income' ? t.good : t.accent }]}>
                  <Text style={{ color: on ? '#fff' : t.text2, fontSize: 15, fontWeight: '700' }}>{label}</Text>
                </PopPressable>
              )
            })}
          </View>

          <Glass radius={28} style={styles.amountCard}>
            <FadeIn key={f.category} y={0} scale={0.82} style={[styles.catBadge, { backgroundColor: alpha(accent, 0.18) }]}><Text style={{ fontSize: 15 }}>{ICONS[f.category]} </Text><Text style={{ color: t.text, fontWeight: '600', fontSize: 13 }}>{f.category}</Text></FadeIn>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
              <Text style={{ color: t.text2, fontSize: 38, fontWeight: '700', fontFamily: rounded, marginRight: 4 }}>$</Text>
              <TextInput style={{ color: t.text, fontSize: 56, fontWeight: '800', fontFamily: rounded, minWidth: 100, fontVariant: ['tabular-nums'] }} value={f.amount}
                editable={!saving} onChangeText={(v) => set('amount', v)} placeholder="0.00" placeholderTextColor={alpha(t.text2, 0.5)}
                keyboardType="decimal-pad" autoFocus={!editing} accessibilityLabel="Amount" />
            </View>
          </Glass>

          {!editing && recent.some((e) => isIncome(e) === income) && (
            <View style={{ gap: 8 }}>
              <Text style={[styles.label, { color: t.text2 }]}>USE A RECENT {income ? 'INCOME' : 'EXPENSE'}</Text>
              <Text style={{ color: t.text2, fontSize: 13 }}>Prefill for today, then review and save.</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} keyboardShouldPersistTaps="handled" contentContainerStyle={{ gap: 8 }}>
                {recent.filter((e) => isIncome(e) === income).map((expense) => (
                  <PopPressable key={expense.id} disabled={saving}
                    onPress={() => { setF(repeatExpense(expense)); setError(''); Haptics.selectionAsync().catch(() => {}) }}
                    accessibilityRole="button" accessibilityLabel={`Use ${expense.description}, ${money(expense.amount)}, ${expense.category}`}
                    accessibilityHint="Fills the form using today's date. Does not save an expense."
                    style={[styles.recent, { backgroundColor: t.chip, borderColor: t.glassEdge }]}>
                    <Text style={{ color: t.text, fontWeight: '700' }} numberOfLines={1}>{ICONS[expense.category]} {expense.description}</Text>
                    <Text style={{ color: t.text2, fontSize: 13 }}>{money(expense.amount)} · {expense.category}</Text>
                  </PopPressable>
                ))}
              </ScrollView>
            </View>
          )}

          <View style={{ gap: 8 }}>
            <Text style={[styles.label, { color: t.text2 }]}>CATEGORY</Text>
            <View style={styles.grid}>
              {categories.map((c) => {
                const on = f.category === c
                return (
                  <PopPressable key={c} disabled={saving} onPress={() => { Haptics.selectionAsync().catch(() => {}); set('category', c) }} accessibilityRole="radio" accessibilityState={{ selected: on }}
                    style={[styles.tile, { backgroundColor: on ? alpha(t.cat(c), 0.2) : t.chip, borderColor: on ? t.cat(c) : t.glassEdge }]}>
                    <Text style={{ fontSize: 24 }}>{ICONS[c]}</Text>
                    <Text style={{ color: t.text, fontSize: 11.5, fontWeight: on ? '700' : '500' }} numberOfLines={1} adjustsFontSizeToFit>{c}</Text>
                  </PopPressable>
                )
              })}
            </View>
          </View>

          <Glass radius={20}>
            <TextInput style={{ color: t.text, fontSize: 16, paddingHorizontal: 16, paddingVertical: 15 }} value={f.description} editable={!saving} onChangeText={(v) => set('description', v)}
              placeholder={income ? 'Where is it from?' : 'What was it for?'} placeholderTextColor={t.text2} maxLength={120} returnKeyType="done" onSubmitEditing={submit} accessibilityLabel="Description" />
            <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: t.line, marginLeft: 16 }} />
            <View style={styles.dateRow}>
              <Text style={{ color: t.text, fontSize: 16 }}>Date</Text>
              <DateTimePicker disabled={saving} value={fromISO(f.date)} mode="date" display="compact" onValueChange={(_, d) => d && set('date', toISO(d))} accentColor={t.accent} />
            </View>
          </Glass>

          {!!error && <Text style={{ color: t.danger, fontSize: 14, textAlign: 'center' }} accessibilityRole="alert">{error}</Text>}

          {editing && (
            <PopPressable disabled={saving} onPress={() => onDelete(editing)} style={[styles.del, { backgroundColor: alpha(t.danger, 0.12) }]} accessibilityRole="button">
              <Text style={{ color: t.danger, fontSize: 16, fontWeight: '700' }}>{income ? 'Delete Income' : 'Delete Expense'}</Text>
            </PopPressable>
          )}
        </ScrollView>

        <View style={styles.footer}>
          <PopPressable disabled={saving} onPress={submit} pressScale={0.97} accessibilityRole="button" accessibilityState={{ disabled: saving, busy: saving }}>
              <LinearGradient colors={income ? [t.good, t.good] : [t.hero[1], t.hero[2]]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.save}>
                <Text style={{ color: '#fff', fontSize: 17, fontWeight: '800' }}>{saving ? 'Saving…' : editing ? 'Save Changes' : income ? 'Add Income' : 'Add Expense'}</Text>
              </LinearGradient>
          </PopPressable>
        </View>
      </View>
  )
}

const styles = StyleSheet.create({
  kinds: { flexDirection: 'row', padding: 4, borderRadius: 99, borderWidth: 1 },
  kind: { flex: 1, alignItems: 'center', paddingVertical: 10, borderRadius: 99 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 18, paddingBottom: 6 },
  amountCard: { alignItems: 'center', paddingVertical: 20, gap: 8 },
  catBadge: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 99 },
  label: { fontSize: 12, fontWeight: '700', letterSpacing: 0.6, marginLeft: 4 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  tile: { width: '22.6%', aspectRatio: 1, borderRadius: 18, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center', gap: 4, paddingHorizontal: 4 },
  recent: { maxWidth: 220, padding: 12, borderWidth: 1, borderRadius: 16, gap: 5 },
  dateRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, minHeight: 52 },
  del: { alignItems: 'center', padding: 15, borderRadius: 16 },
  footer: { paddingHorizontal: 16, paddingBottom: 20, paddingTop: 4 },
  save: { paddingVertical: 17, borderRadius: 99, alignItems: 'center' },
})
