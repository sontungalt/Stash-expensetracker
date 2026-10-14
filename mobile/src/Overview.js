import { LinearGradient } from 'expo-linear-gradient'
import { useMemo } from 'react'
import { Animated, StyleSheet, Text, View } from 'react-native'
import { Donut, MonthBars } from './charts'
import { FadeIn, PopPressable, useTween } from './hooks'
import { Glass } from './Glass'
import { usePullToRefresh } from './PullToRefresh'
import { categoryTotals, money, monthKey, monthLabel, monthlyTotals, shiftMonth, summarize, todayISO } from './lib'
import { ICONS, rounded, useTheme } from './theme'

function Hero({ total, income, net, delta, period, count, topCat, avgLabel, avg }) {
  const t = useTheme()
  const shown = useTween(total, 900)
  return (
    <LinearGradient colors={t.hero} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.hero}>
      <View style={styles.glow1} pointerEvents="none" />
      <View style={styles.glow2} pointerEvents="none" />
      <Text style={styles.heroLabel}>Total spent · {period}</Text>
      <Text style={[styles.heroAmt, { fontFamily: rounded }]} adjustsFontSizeToFit numberOfLines={1} accessibilityLabel={money(total)}>{money(shown)}</Text>
      <View style={styles.pills}>
        {delta !== null && (
          <View style={[styles.pill, { backgroundColor: delta > 0 ? 'rgba(255,120,110,0.28)' : 'rgba(80,220,130,0.26)' }]}>
            <Text style={styles.pillTxt}>{delta > 0 ? '↑' : '↓'} {Math.abs(delta).toFixed(0)}% vs last month</Text>
          </View>
        )}
        <View style={styles.pill}><Text style={styles.pillTxt}>{count} transaction{count === 1 ? '' : 's'}</Text></View>
        {income > 0 && <View style={[styles.pill, { backgroundColor: 'rgba(80,220,130,0.26)' }]}><Text style={styles.pillTxt}>In {money(income)}</Text></View>}
        {income > 0 && (
          <View style={[styles.pill, { backgroundColor: net < 0 ? 'rgba(255,120,110,0.28)' : 'rgba(80,220,130,0.26)' }]}>
            <Text style={styles.pillTxt}>{net < 0 ? `Over by ${money(-net)}` : `${money(net)} left`}</Text>
          </View>
        )}
      </View>
      <View style={styles.heroStats}>
        <View style={{ flex: 1 }}>
          <Text style={styles.statLbl}>Top category</Text>
          <Text style={styles.statVal}>{topCat ? `${ICONS[topCat.name]} ${topCat.name}` : '—'}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={styles.statLbl}>{avgLabel}</Text>
          <Text style={[styles.statVal, { fontFamily: rounded }]}>{money(avg)}</Text>
        </View>
      </View>
    </LinearGradient>
  )
}

export default function Overview({ expenses, selected, onSelect, onLoadSample, onAdd, onRefresh }) {
  const t = useTheme()
  const pull = usePullToRefresh(onRefresh)
  const nowKey = todayISO().slice(0, 7)
  const latest = useMemo(() => expenses.reduce((m, e) => (monthKey(e.date) > m ? monthKey(e.date) : m), nowKey), [expenses, nowKey])
  const monthly = useMemo(() => monthlyTotals(expenses, latest, 6), [expenses, latest])
  const scoped = useMemo(() => (selected === 'all' ? expenses : expenses.filter((e) => monthKey(e.date) === selected)), [expenses, selected])
  const cats = useMemo(() => categoryTotals(scoped), [scoped])

  const { income, spent: total, net } = summarize(scoped)
  const prev = selected === 'all' ? null : summarize(expenses.filter((e) => monthKey(e.date) === shiftMonth(selected, -1))).spent
  const delta = prev ? ((total - prev) / prev) * 100 : null
  const period = selected === 'all' ? 'All time' : monthLabel(selected, true)
  const months = new Set(expenses.map((e) => monthKey(e.date))).size || 1
  let avgLabel = 'Avg per month', avg = summarize(expenses).spent / months
  if (selected !== 'all') {
    const [y, m] = selected.split('-').map(Number)
    const now = new Date()
    const days = y === now.getFullYear() && m === now.getMonth() + 1 ? now.getDate() : new Date(y, m, 0).getDate()
    avgLabel = 'Avg per day'
    avg = total / days
  }

  if (expenses.length === 0)
    return (
      <View style={styles.empty}>
        <FadeIn style={{ alignItems: 'center' }}>
          <View style={[styles.emptyIcon, { backgroundColor: t.accentSoft }]}><Text style={{ fontSize: 44 }}>💸</Text></View>
          <Text style={[styles.emptyTitle, { color: t.text }]}>Track your first expense</Text>
          <Text style={{ color: t.text2, textAlign: 'center', fontSize: 15, lineHeight: 21, marginBottom: 24 }}>See where your money goes with monthly and category breakdowns.</Text>
          <PopPressable onPress={onAdd} style={[styles.btn, { backgroundColor: t.accent }]} accessibilityRole="button"><Text style={{ color: t.onAccent, fontWeight: '700', fontSize: 17 }}>Add Expense</Text></PopPressable>
          <PopPressable onPress={onLoadSample} style={{ padding: 16 }} accessibilityRole="button"><Text style={{ color: t.accent, fontSize: 16, fontWeight: '600' }}>or try with sample data</Text></PopPressable>
        </FadeIn>
      </View>
    )

  return (
    <View style={{ flex: 1 }}>
    {pull.indicator}
    <Animated.ScrollView {...pull.scrollProps} contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 6, gap: 20, paddingBottom: 150 }} showsVerticalScrollIndicator={false}>
      <FadeIn>
        <Hero total={total} income={income} net={net} delta={delta} period={period} count={scoped.length} topCat={cats[0]} avgLabel={avgLabel} avg={avg} />
      </FadeIn>

      <FadeIn delay={90}>
        <Glass radius={28} style={styles.card}>
          <Text style={[styles.h, { color: t.text }]}>Monthly spending</Text>
          <MonthBars data={monthly} selected={selected} onSelect={onSelect} />
        </Glass>
      </FadeIn>

      <FadeIn delay={180}>
        <Glass radius={28} style={styles.card}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
            <Text style={[styles.h, { color: t.text, marginBottom: 0 }]}>By category</Text>
            <Text style={{ color: t.text2, fontSize: 13 }}>{period}</Text>
          </View>
          {cats.length ? <Donut data={cats} /> : <Text style={{ color: t.text2, textAlign: 'center', paddingVertical: 24 }}>No expenses in this period.</Text>}
        </Glass>
      </FadeIn>
    </Animated.ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  hero: { borderRadius: 28, padding: 22, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.28)', shadowColor: '#2a78d6', shadowOpacity: 0.35, shadowRadius: 24, shadowOffset: { width: 0, height: 12 } },
  glow1: { position: 'absolute', width: 220, height: 220, borderRadius: 110, backgroundColor: 'rgba(255,255,255,0.10)', top: -90, right: -60 },
  glow2: { position: 'absolute', width: 160, height: 160, borderRadius: 80, backgroundColor: 'rgba(255,255,255,0.06)', bottom: -70, left: -40 },
  heroLabel: { color: 'rgba(255,255,255,0.72)', fontSize: 14, fontWeight: '500' },
  heroAmt: { color: '#fff', fontSize: 46, fontWeight: '800', letterSpacing: -1, fontVariant: ['tabular-nums'], marginTop: 4 },
  pills: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 },
  pill: { backgroundColor: 'rgba(255,255,255,0.16)', paddingHorizontal: 11, paddingVertical: 6, borderRadius: 99 },
  pillTxt: { color: '#fff', fontSize: 12.5, fontWeight: '600' },
  heroStats: { flexDirection: 'row', marginTop: 20, paddingTop: 16, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: 'rgba(255,255,255,0.28)' },
  statLbl: { color: 'rgba(255,255,255,0.65)', fontSize: 12, marginBottom: 3 },
  statVal: { color: '#fff', fontSize: 17, fontWeight: '700' },
  card: { padding: 18 },
  h: { fontSize: 18, fontWeight: '800', marginBottom: 10, letterSpacing: -0.3 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32, paddingBottom: 120 },
  emptyIcon: { width: 104, height: 104, borderRadius: 52, alignItems: 'center', justifyContent: 'center', marginBottom: 20 },
  emptyTitle: { fontSize: 24, fontWeight: '800', marginBottom: 8, letterSpacing: -0.4 },
  btn: { paddingHorizontal: 32, paddingVertical: 16, borderRadius: 99 },
})
