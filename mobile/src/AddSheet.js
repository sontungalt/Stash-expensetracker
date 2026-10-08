import DateTimePicker from '@react-native-community/datetimepicker'
import { LinearGradient } from 'expo-linear-gradient'
import { useEffect, useState } from 'react'
import { Animated, Keyboard, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native'
import * as Haptics from 'expo-haptics'
import { Glass, Backdrop } from './Glass'
import { usePressScale } from './hooks'
import { CATEGORIES, fromISO, toISO } from './lib'
import { alpha, ICONS, rounded, useTheme } from './theme'

const blank = () => ({ description: '', amount: '', category: 'Food', date: toISO(new Date()) })
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

export default function AddSheet({ visible, editing, onClose, onSave, onDelete }) {
  const t = useTheme()
  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      {/* Form remounts per open, so its state always starts fresh (or from the expense being edited). */}
      {visible && <Form key={editing?.id ?? 'new'} t={t} editing={editing} onClose={onClose} onSave={onSave} onDelete={onDelete} />}
    </Modal>
  )
}

function Form({ t, editing, onClose, onSave, onDelete }) {
  const [f, setF] = useState(() => (editing ? { ...editing, amount: String(editing.amount) } : blank()))
  const [error, setError] = useState('')
  const press = usePressScale(0.97)
  const kb = useKeyboardHeight()

  const set = (k, v) => setF((x) => ({ ...x, [k]: v }))
  const fail = (m) => { setError(m); buzz(Haptics.NotificationFeedbackType.Error) }

  function submit() {
    const amount = parseFloat(f.amount.replace(',', '.'))
    if (!(amount > 0)) return fail('Enter an amount greater than zero.')
    if (!f.description.trim()) return fail('Add a short description.')
    buzz(Haptics.NotificationFeedbackType.Success)
    onSave({ description: f.description.trim(), amount: Math.round(amount * 100) / 100, category: f.category, date: f.date })
  }

  const accent = t.cat(f.category)

  return (
      <View style={{ flex: 1, paddingBottom: kb }}>
        <Backdrop />
        <View style={styles.header}>
          <Pressable onPress={onClose} hitSlop={12} accessibilityRole="button"><Text style={{ color: t.text2, fontSize: 17 }}>Cancel</Text></Pressable>
          <Text style={{ color: t.text, fontSize: 17, fontWeight: '700' }}>{editing ? 'Edit Expense' : 'New Expense'}</Text>
          <View style={{ width: 52 }} />
        </View>

        <ScrollView contentContainerStyle={{ padding: 16, gap: 20, paddingBottom: 24 }} keyboardShouldPersistTaps="handled" keyboardDismissMode="interactive">
          <Glass radius={28} style={styles.amountCard}>
            <View style={[styles.catBadge, { backgroundColor: alpha(accent, 0.18) }]}><Text style={{ fontSize: 15 }}>{ICONS[f.category]} </Text><Text style={{ color: t.text, fontWeight: '600', fontSize: 13 }}>{f.category}</Text></View>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
              <Text style={{ color: t.text2, fontSize: 38, fontWeight: '700', fontFamily: rounded, marginRight: 4 }}>$</Text>
              <TextInput style={{ color: t.text, fontSize: 56, fontWeight: '800', fontFamily: rounded, minWidth: 100, fontVariant: ['tabular-nums'] }} value={f.amount}
                onChangeText={(v) => set('amount', v.replace(/[^0-9.,]/g, ''))} placeholder="0.00" placeholderTextColor={alpha(t.text2, 0.5)}
                keyboardType="decimal-pad" autoFocus={!editing} accessibilityLabel="Amount" />
            </View>
          </Glass>

          <View style={{ gap: 8 }}>
            <Text style={[styles.label, { color: t.text2 }]}>CATEGORY</Text>
            <View style={styles.grid}>
              {CATEGORIES.map((c) => {
                const on = f.category === c
                return (
                  <Pressable key={c} onPress={() => { Haptics.selectionAsync().catch(() => {}); set('category', c) }} accessibilityRole="radio" accessibilityState={{ selected: on }}
                    style={[styles.tile, { backgroundColor: on ? alpha(t.cat(c), 0.2) : t.chip, borderColor: on ? t.cat(c) : t.glassEdge }]}>
                    <Text style={{ fontSize: 24 }}>{ICONS[c]}</Text>
                    <Text style={{ color: t.text, fontSize: 11.5, fontWeight: on ? '700' : '500' }} numberOfLines={1} adjustsFontSizeToFit>{c}</Text>
                  </Pressable>
                )
              })}
            </View>
          </View>

          <Glass radius={20}>
            <TextInput style={{ color: t.text, fontSize: 16, paddingHorizontal: 16, paddingVertical: 15 }} value={f.description} onChangeText={(v) => set('description', v)}
              placeholder="What was it for?" placeholderTextColor={t.text2} maxLength={120} returnKeyType="done" onSubmitEditing={submit} accessibilityLabel="Description" />
            <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: t.line, marginLeft: 16 }} />
            <View style={styles.dateRow}>
              <Text style={{ color: t.text, fontSize: 16 }}>Date</Text>
              <DateTimePicker value={fromISO(f.date)} mode="date" display="compact" onValueChange={(_, d) => d && set('date', toISO(d))} accentColor={t.accent} />
            </View>
          </Glass>

          {!!error && <Text style={{ color: t.danger, fontSize: 14, textAlign: 'center' }} accessibilityRole="alert">{error}</Text>}

          {editing && (
            <Pressable onPress={() => onDelete(editing)} style={[styles.del, { backgroundColor: alpha(t.danger, 0.12) }]} accessibilityRole="button">
              <Text style={{ color: t.danger, fontSize: 16, fontWeight: '700' }}>Delete Expense</Text>
            </Pressable>
          )}
        </ScrollView>

        <View style={styles.footer}>
          <Pressable onPress={submit} onPressIn={press.onPressIn} onPressOut={press.onPressOut} accessibilityRole="button">
            <Animated.View style={press.style}>
              <LinearGradient colors={[t.hero[1], t.hero[2]]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.save}>
                <Text style={{ color: '#fff', fontSize: 17, fontWeight: '800' }}>{editing ? 'Save Changes' : 'Add Expense'}</Text>
              </LinearGradient>
            </Animated.View>
          </Pressable>
        </View>
      </View>
  )
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 18, paddingBottom: 6 },
  amountCard: { alignItems: 'center', paddingVertical: 20, gap: 8 },
  catBadge: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 99 },
  label: { fontSize: 12, fontWeight: '700', letterSpacing: 0.6, marginLeft: 4 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  tile: { width: '22.6%', aspectRatio: 1, borderRadius: 18, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center', gap: 4, paddingHorizontal: 4 },
  dateRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, minHeight: 52 },
  del: { alignItems: 'center', padding: 15, borderRadius: 16 },
  footer: { paddingHorizontal: 16, paddingBottom: 20, paddingTop: 4 },
  save: { paddingVertical: 17, borderRadius: 99, alignItems: 'center' },
})
