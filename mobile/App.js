import { StatusBar } from 'expo-status-bar'
import { useEffect, useMemo, useRef, useState } from 'react'
import { ActivityIndicator, Alert, Animated, Pressable, StyleSheet, Text, View } from 'react-native'
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context'
import Svg, { Path, Rect } from 'react-native-svg'
import * as Haptics from 'expo-haptics'
import AddSheet from './src/AddSheet'
import { Backdrop, Glass } from './src/Glass'
import History from './src/History'
import OriginDropdown, { Chevron } from './src/OriginDropdown'
import Overview from './src/Overview'
import { usePressScale } from './src/hooks'
import { money, monthKey, monthLabel, sampleExpenses } from './src/lib'
import { useExpenses } from './src/store'
import { rounded, useTheme } from './src/theme'

const GridIcon = ({ c }) => (
  <Svg width={22} height={22} viewBox="0 0 24 24" fill={c}>
    <Rect x="3" y="3" width="8" height="8" rx="2.5" /><Rect x="13" y="3" width="8" height="8" rx="2.5" opacity=".55" />
    <Rect x="3" y="13" width="8" height="8" rx="2.5" opacity=".55" /><Rect x="13" y="13" width="8" height="8" rx="2.5" />
  </Svg>
)
const ListIcon = ({ c }) => (
  <Svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth={2.4} strokeLinecap="round">
    <Path d="M9 6.5h11M9 12h11M9 17.5h11" /><Path d="M4 6.5h.01M4 12h.01M4 17.5h.01" />
  </Svg>
)
const PlusIcon = () => (
  <Svg width={26} height={26} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.8} strokeLinecap="round"><Path d="M12 5v14M5 12h14" /></Svg>
)

const PILL_W = 252, ITEM_W = 76, PAD = 8

function TabBar({ tab, setTab, onAdd, bottom }) {
  const t = useTheme()
  const x = useRef(new Animated.Value(tab === 'overview' ? 0 : 1)).current
  const plus = usePressScale(0.88)
  useEffect(() => { Animated.spring(x, { toValue: tab === 'overview' ? 0 : 1, useNativeDriver: true, speed: 18, bounciness: 9 }).start() }, [tab, x])
  const go = (k) => { if (k !== tab) { Haptics.selectionAsync().catch(() => {}); setTab(k) } }
  const items = [['overview', 'Overview', GridIcon], ['history', 'Activity', ListIcon]]

  return (
    <View style={[styles.tabWrap, { bottom }]} pointerEvents="box-none">
      <Glass radius={33} interactive style={[styles.pill]}>
        <Animated.View style={[styles.indicator, { backgroundColor: t.accentSoft, transform: [{ translateX: x.interpolate({ inputRange: [0, 1], outputRange: [PAD, PILL_W - PAD - ITEM_W] }) }] }]} />
        {items.slice(0, 1).map(([k, label, Icon]) => (
          <Pressable key={k} onPress={() => go(k)} style={styles.item} accessibilityRole="tab" accessibilityState={{ selected: tab === k }} accessibilityLabel={label}>
            <Icon c={tab === k ? t.accent : t.text2} />
            <Text style={[styles.itemTxt, { color: tab === k ? t.accent : t.text2 }]}>{label}</Text>
          </Pressable>
        ))}
        <Pressable onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {}); onAdd() }} onPressIn={plus.onPressIn} onPressOut={plus.onPressOut}
          accessibilityRole="button" accessibilityLabel="Add expense">
          <Animated.View style={plus.style}>
            <View style={[styles.plus, { borderRadius: 27, overflow: 'hidden', backgroundColor: t.accent }]}>
              <Glass radius={27} tint={t.accent} interactive style={StyleSheet.absoluteFill} />
              <View style={styles.plusIcon} pointerEvents="none"><PlusIcon /></View>
            </View>
          </Animated.View>
        </Pressable>
        {items.slice(1).map(([k, label, Icon]) => (
          <Pressable key={k} onPress={() => go(k)} style={styles.item} accessibilityRole="tab" accessibilityState={{ selected: tab === k }} accessibilityLabel={label}>
            <Icon c={tab === k ? t.accent : t.text2} />
            <Text style={[styles.itemTxt, { color: tab === k ? t.accent : t.text2 }]}>{label}</Text>
          </Pressable>
        ))}
      </Glass>
    </View>
  )
}

function Shell() {
  const t = useTheme()
  const insets = useSafeAreaInsets()
  const { expenses, ready, add, addMany, update, remove, reload } = useExpenses()
  const [tab, setTab] = useState('overview')
  const [selected, setSelected] = useState('all')
  const [sheet, setSheet] = useState({ open: false, editing: null })

  const scoped = useMemo(() => (selected === 'all' ? expenses : expenses.filter((e) => monthKey(e.date) === selected)), [expenses, selected])
  const months = useMemo(() => [...new Set(expenses.map((e) => monthKey(e.date)))].sort().reverse(), [expenses])
  const periodLabel = selected === 'all' ? 'All time' : monthLabel(selected, true)

  const open = (editing = null) => setSheet({ open: true, editing })
  const close = () => setSheet({ open: false, editing: null })
  const save = (data) => {
    sheet.editing ? update(sheet.editing.id, data) : add(data)
    close()
  }
  const del = (r) =>
    Alert.alert('Delete expense?', `${r.description} · ${money(r.amount)}`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => { Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning).catch(() => {}); remove(r.id); close() } },
    ])

  if (!ready) return <View style={[styles.fill, { backgroundColor: t.bg, justifyContent: 'center' }]}><ActivityIndicator /></View>

  return (
    <View style={[styles.fill, { paddingTop: insets.top }]}>
      <Backdrop />
      <View style={styles.header}>
        <View>
          <Text style={{ color: t.text2, fontSize: 13, fontWeight: '600' }}>{tab === 'overview' ? 'Your spending' : periodLabel}</Text>
          <Text style={[styles.title, { color: t.text, fontFamily: rounded }]}>{tab === 'overview' ? 'Overview' : 'Activity'}</Text>
        </View>
        {expenses.length > 0 && (
          <OriginDropdown label={`Period: ${periodLabel}`} minWidth={210}
            items={[{ id: 'all', label: 'All time', icon: '♾️', selected: selected === 'all', onSelect: () => setSelected('all') },
              ...months.map((k) => ({ id: k, label: monthLabel(k, true), selected: selected === k, onSelect: () => setSelected(k) }))]}
            trigger={({ open: isOpen }) => (
              <Glass radius={99} interactive style={styles.period}>
                <View style={styles.periodIn}>
                  <Text style={{ color: t.text, fontSize: 14, fontWeight: '700' }}>{selected === 'all' ? 'All time' : monthLabel(selected, true)}</Text>
                  <Chevron open={isOpen} color={t.text2} />
                </View>
              </Glass>
            )} />
        )}
      </View>

      <View style={styles.fill}>
        {tab === 'overview'
          ? <Overview expenses={expenses} selected={selected} onSelect={setSelected} onLoadSample={() => addMany(sampleExpenses())} onAdd={() => open()} onRefresh={reload} />
          : <History rows={scoped} periodLabel={periodLabel} onEdit={open} onRefresh={reload} />}
      </View>

      <TabBar tab={tab} setTab={setTab} onAdd={() => open()} bottom={Math.max(insets.bottom, 12) + 4} />
      <AddSheet visible={sheet.open} editing={sheet.editing} onClose={close} onSave={save} onDelete={del} />
      <StatusBar style="auto" />
    </View>
  )
}

export default function App() {
  return <SafeAreaProvider><Shell /></SafeAreaProvider>
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', paddingHorizontal: 20, paddingTop: 10, paddingBottom: 14 },
  title: { fontSize: 34, fontWeight: '800', letterSpacing: -0.8 },
  period: { marginBottom: 6 },
  periodIn: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 16, paddingVertical: 10 },
  tabWrap: { position: 'absolute', left: 0, right: 0, alignItems: 'center' },
  pill: { width: PILL_W, height: 66, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: PAD },
  indicator: { position: 'absolute', top: 8, left: 0, width: ITEM_W, height: 50, borderRadius: 25 },
  item: { width: ITEM_W, height: 50, alignItems: 'center', justifyContent: 'center', gap: 2 },
  itemTxt: { fontSize: 10.5, fontWeight: '700' },
  plus: { width: 54, height: 54 },
  plusIcon: { flex: 1, alignItems: 'center', justifyContent: 'center' },
})
