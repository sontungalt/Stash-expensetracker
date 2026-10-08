import { useMemo, useState } from 'react'
import { Animated, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native'
import { FadeIn } from './hooks'
import { Glass } from './Glass'
import LiquidToggle from './LiquidToggle'
import OriginDropdown from './OriginDropdown'
import { usePullToRefresh } from './PullToRefresh'
import { CATEGORIES, dayLabel, fromISO, money, todayISO } from './lib'
import { alpha, ICONS, rounded, useTheme } from './theme'

const SORTS = [
  { key: 'date', label: 'Newest first', hint: 'Most recent on top', icon: '🕐' }, { key: 'dateAsc', label: 'Oldest first', hint: 'Where it all started', icon: '📅' },
  { key: 'amount', label: 'Highest amount', hint: 'Biggest spends first', icon: '📈' }, { key: 'amountAsc', label: 'Lowest amount', hint: 'Smallest spends first', icon: '📉' },
]
const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const CHUNK = 25

const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const heading = (date) => {
  const y = new Date(); y.setDate(y.getDate() - 1)
  if (date === todayISO()) return 'Today'
  if (date === iso(y)) return 'Yesterday'
  const base = `${WD[fromISO(date).getDay()]}, ${dayLabel(date).replace(/, \d{4}$/, '')}`
  return date.slice(0, 4) === todayISO().slice(0, 4) ? base : `${base} ${date.slice(0, 4)}`
}

function Row({ r, last, onEdit }) {
  const t = useTheme()
  return (
    <Pressable onPress={() => onEdit(r)} accessibilityRole="button"
      accessibilityLabel={`${r.description}, ${money(r.amount)}, ${r.category}, ${dayLabel(r.date)}. Tap to edit.`}
      style={({ pressed }) => [styles.row, { backgroundColor: pressed ? t.line : 'transparent' }]}>
      <View style={[styles.icon, { backgroundColor: alpha(t.cat(r.category), 0.16) }]}><Text style={{ fontSize: 20 }}>{ICONS[r.category]}</Text></View>
      <View style={[styles.rowBody, !last && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: t.line }]}>
        <View style={{ flex: 1 }}>
          <Text style={{ color: t.text, fontSize: 16, fontWeight: '600' }} numberOfLines={1}>{r.description}</Text>
          <Text style={{ color: t.text2, fontSize: 13, marginTop: 2 }}>{r.category}</Text>
        </View>
        <Text style={{ color: t.text, fontSize: 16, fontWeight: '700', fontVariant: ['tabular-nums'], fontFamily: rounded }}>{money(r.amount)}</Text>
      </View>
    </Pressable>
  )
}

function Group({ g, index, onEdit }) {
  const t = useTheme()
  return (
    <FadeIn delay={Math.min(index, 5) * 50} y={10} style={styles.group}>
      {!!g.title && (
        <View style={styles.dayHead}>
          <Text style={{ color: t.text, fontSize: 15, fontWeight: '800' }}>{g.title}</Text>
          {g.total != null && <Text style={{ color: t.text2, fontSize: 13, fontWeight: '600', fontVariant: ['tabular-nums'] }}>{money(g.total)}</Text>}
        </View>
      )}
      <Glass radius={24} style={styles.card}>
        {g.rows.map((r, i) => <Row key={r.id} r={r} last={i === g.rows.length - 1} onEdit={onEdit} />)}
      </Glass>
    </FadeIn>
  )
}

export default function History({ rows, periodLabel, onEdit, onRefresh }) {
  const t = useTheme()
  const pull = usePullToRefresh(onRefresh)
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('All')
  const [sort, setSort] = useState('date')
  const [byDay, setByDay] = useState(true)

  const { groups, count, sum } = useMemo(() => {
    const n = q.trim().toLowerCase()
    const f = rows.filter((r) => (cat === 'All' || r.category === cat) && (!n || r.description.toLowerCase().includes(n)))
    const dir = sort.endsWith('Asc') ? 1 : -1
    const by = sort.startsWith('amount') ? (a, b) => a.amount - b.amount : (a, b) => a.date.localeCompare(b.date)
    f.sort((a, b) => by(a, b) * dir)
    const out = []
    if (sort.startsWith('date') && byDay) {
      const days = new Map()
      f.forEach((r) => { if (!days.has(r.date)) days.set(r.date, []); days.get(r.date).push(r) })
      days.forEach((list, date) => out.push({ id: date, title: heading(date), total: list.reduce((s, r) => s + r.amount, 0), rows: list }))
    } else {
      for (let i = 0; i < f.length; i += CHUNK) out.push({ id: `c${i}`, title: i === 0 ? (sort.startsWith('date') ? 'All expenses' : SORTS.find((s) => s.key === sort).label) : '', rows: f.slice(i, i + CHUNK) })
    }
    return { groups: out, count: f.length, sum: f.reduce((s, r) => s + r.amount, 0) }
  }, [rows, q, cat, sort, byDay])

  return (
    <View style={{ flex: 1 }}>
    {pull.indicator}
    <Animated.FlatList
      {...pull.scrollProps}
      data={groups}
      keyExtractor={(g) => g.id}
      keyboardDismissMode="on-drag"
      showsVerticalScrollIndicator={false}
      contentContainerStyle={{ paddingBottom: 150 }}
      ListHeaderComponent={
        <View style={{ paddingTop: 4, paddingBottom: 6 }}>
          <View style={styles.searchRow}>
            <Glass radius={16} interactive style={styles.search}>
              <Text style={{ color: t.text2, fontSize: 15 }}>⌕</Text>
              <TextInput value={q} onChangeText={setQ} placeholder="Search" placeholderTextColor={t.text2} clearButtonMode="while-editing" autoCorrect={false}
                style={{ flex: 1, color: t.text, fontSize: 16, paddingVertical: 12 }} accessibilityLabel="Search transactions" />
            </Glass>
            <OriginDropdown label={`Sort: ${SORTS.find((s) => s.key === sort).label}`} minWidth={230}
              items={SORTS.map((s) => ({ id: s.key, label: s.label, description: s.hint, icon: s.icon, selected: sort === s.key, onSelect: () => setSort(s.key) }))}
              trigger={() => (
                <View style={styles.sortWrap}>
                  <Glass radius={16} interactive tint={sort === 'date' ? undefined : t.accent} style={styles.sortBtn}>
                    <Text style={{ color: sort === 'date' ? t.text : '#fff', fontSize: 18, fontWeight: '700' }}>⇅</Text>
                  </Glass>
                </View>
              )} />
          </View>

          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
            {['All', ...CATEGORIES].map((c) => {
              const on = cat === c
              return (
                <Pressable key={c} onPress={() => setCat(on && c !== 'All' ? 'All' : c)} accessibilityRole="button" accessibilityState={{ selected: on }}
                  style={[styles.chip, { backgroundColor: on ? t.accent : t.chip, borderColor: on ? t.accent : t.glassEdge }]}>
                  <Text style={{ color: on ? t.onAccent : t.text, fontSize: 13.5, fontWeight: on ? '700' : '500' }}>{c === 'All' ? 'All' : `${ICONS[c]} ${c}`}</Text>
                </Pressable>
              )
            })}
          </ScrollView>

          <View style={styles.summaryRow}>
            <Text style={{ flex: 1, fontSize: 14 }} numberOfLines={1}>
              <Text style={{ color: t.text, fontWeight: '800' }}>{money(sum)}</Text>
              <Text style={{ color: t.text2 }}> · {count} · {periodLabel}</Text>
            </Text>
            {sort.startsWith('date') && (
              <>
                <Text style={{ color: t.text2, fontSize: 13, fontWeight: '600' }}>Group by day</Text>
                <LiquidToggle value={byDay} onChange={setByDay} label="Group by day" />
              </>
            )}
          </View>
        </View>
      }
      ListEmptyComponent={<View style={{ alignItems: 'center', padding: 56 }}><Text style={{ fontSize: 40 }}>🔍</Text><Text style={{ color: t.text2, marginTop: 10, fontSize: 15 }}>No expenses match.</Text></View>}
      renderItem={({ item, index }) => <Group g={item} index={index} onEdit={onEdit} />}
    />
    </View>
  )
}

const styles = StyleSheet.create({
  searchRow: { flexDirection: 'row', gap: 10, paddingHorizontal: 20 },
  search: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 14 },
  sortWrap: { width: 48 },
  sortBtn: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  chips: { gap: 8, paddingHorizontal: 20, paddingTop: 14, paddingBottom: 4 },
  chip: { paddingHorizontal: 13, paddingVertical: 7, borderRadius: 99, borderWidth: 1 },
  summaryRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 22, paddingTop: 16 },
  group: { marginHorizontal: 20, marginTop: 18 },
  dayHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', paddingHorizontal: 4, paddingBottom: 9 },
  card: { paddingLeft: 14 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingLeft: 0 },
  icon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  rowBody: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 14, paddingRight: 16 },
})
