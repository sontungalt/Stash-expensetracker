import { useRef, useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import Svg, { Circle, Defs, G, Line, LinearGradient, Path, Stop, Text as SvgText } from 'react-native-svg'
import * as Haptics from 'expo-haptics'
import { useTween } from './hooks'
import { money, moneyShort, monthLabel } from './lib'
import { alpha, ICONS, rounded, useTheme } from './theme'

const tick = () => Haptics.selectionAsync().catch(() => {})

export function Donut({ data, size = 200 }) {
  const t = useTheme()
  const [sel, setSel] = useState(null)
  const total = data.reduce((s, d) => s + d.value, 0)
  const sig = data.map((d) => `${d.name}${d.value}`).join('|')
  const p = useTween(1, 900, sig)
  const stroke = 28
  const r = (size - stroke) / 2
  const C = 2 * Math.PI * r
  const active = data.find((d) => d.name === sel)
  const segs = data.reduce((acc, d) => {
    const before = acc.length ? acc[acc.length - 1].end : 0
    return [...acc, { ...d, start: before, end: before + d.value / total }]
  }, [])

  return (
    <View>
      <View style={{ alignSelf: 'center', width: size, height: size }} accessible accessibilityRole="image"
        accessibilityLabel={`Spending by category. ${data.map((d) => `${d.name} ${money(d.value)}`).join(', ')}`}>
        <Svg width={size} height={size}>
          <Circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={t.line} strokeWidth={stroke} />
          {segs.map((d) => {
            const len = (d.value / total) * C * p
            const off = -d.start * C * p
            return (
              <Circle key={d.name} cx={size / 2} cy={size / 2} r={r} fill="none" stroke={t.cat(d.name)} strokeWidth={stroke}
                strokeOpacity={sel && sel !== d.name ? 0.25 : 1} strokeDasharray={`${Math.max(len - 2.5, 0.01)} ${C}`} strokeDashoffset={off}
                transform={`rotate(-90 ${size / 2} ${size / 2})`} />
            )
          })}
        </Svg>
        <View style={styles.center} pointerEvents="none">
          <Text style={{ fontSize: 26 }}>{active ? ICONS[active.name] : '💸'}</Text>
          <Text style={[styles.small, { color: t.text2 }]}>{active ? active.name : 'Total'}</Text>
          <Text style={[styles.big, { color: t.text, fontFamily: rounded }]} adjustsFontSizeToFit numberOfLines={1}>{money(active ? active.value : total)}</Text>
        </View>
      </View>

      <View style={{ marginTop: 18, gap: 4 }}>
        {data.map((d) => {
          const on = sel === d.name
          const pct = d.value / total
          return (
            <Pressable key={d.name} onPress={() => { tick(); setSel(on ? null : d.name) }} accessibilityRole="button" accessibilityState={{ selected: on }}
              style={({ pressed }) => [styles.row, { backgroundColor: on || pressed ? alpha(t.cat(d.name), 0.12) : 'transparent', opacity: sel && !on ? 0.55 : 1 }]}>
              <View style={[styles.icon, { backgroundColor: alpha(t.cat(d.name), 0.18) }]}><Text style={{ fontSize: 18 }}>{ICONS[d.name]}</Text></View>
              <View style={{ flex: 1, gap: 6 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                  <Text style={{ color: t.text, fontSize: 15, fontWeight: '600' }}>{d.name}</Text>
                  <Text style={{ color: t.text, fontSize: 15, fontWeight: '600', fontVariant: ['tabular-nums'], fontFamily: rounded }}>{money(d.value)}</Text>
                </View>
                <View style={[styles.track, { backgroundColor: t.line }]}>
                  <View style={{ width: `${Math.max(2, pct * 100 * p)}%`, height: '100%', borderRadius: 3, backgroundColor: t.cat(d.name) }} />
                </View>
              </View>
              <Text style={[styles.pct, { color: t.text2 }]}>{Math.round(pct * 100)}%</Text>
            </Pressable>
          )
        })}
      </View>
    </View>
  )
}

const niceMax = (v) => {
  if (v <= 0) return 100
  const p = Math.pow(10, Math.floor(Math.log10(v)))
  const n = v / p
  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * p
}

function Bar({ d, i, slot, axisW, barW, max, y0, plotH, topPad, fill, dim, picked }) {
  const total = useTween(d.total, 650)
  const h = Math.max(total > 0 ? 3 : 0, (total / max) * plotH)
  if (h <= 0) return null
  const cx = axisW + slot * i + slot / 2
  const x0 = cx - barW / 2, x1 = cx + barW / 2, yt = y0 - h
  const rr = Math.min(7, barW / 2, h)
  return (
    <Path d={`M${x0},${y0} L${x0},${yt + rr} Q${x0},${yt} ${x0 + rr},${yt} L${x1 - rr},${yt} Q${x1},${yt} ${x1},${yt + rr} L${x1},${y0} Z`}
      fill={picked ? 'url(#barSel)' : fill} fillOpacity={dim ? 0.28 : 1} />
  )
}

export function MonthBars({ data, selected, onSelect, height = 200 }) {
  const t = useTheme()
  const [w, setW] = useState(0)
  const drag = useRef({ moved: false, was: false, last: -1 })
  const axisW = 42, topPad = 10, bottomPad = 24
  const rawMax = niceMax(Math.max(...data.map((d) => d.total)))
  const max = useTween(rawMax, 600)
  const plotH = height - topPad - bottomPad
  const plotW = Math.max(0, w - axisW)
  const slot = plotW / data.length
  const barW = Math.min(34, slot * 0.58)
  const y0 = topPad + plotH
  const y = (v) => topPad + plotH * (1 - v / (max || 1))
  const ticks = [0, 0.5, 1].map((f) => rawMax * f)
  const focus = data.find((d) => d.key === selected)
  const idxAt = (x) => Math.min(data.length - 1, Math.max(0, Math.floor((x - axisW) / slot)))

  const responder = {
    onStartShouldSetResponder: () => true,
    onMoveShouldSetResponder: () => true,
    onResponderTerminationRequest: () => false,
    onResponderGrant: (e) => {
      const i = idxAt(e.nativeEvent.locationX)
      drag.current = { moved: false, was: data[i].key === selected, last: i }
      tick()
      onSelect(data[i].key)
    },
    onResponderMove: (e) => {
      const i = idxAt(e.nativeEvent.locationX)
      if (i === drag.current.last) return
      drag.current.moved = true
      drag.current.last = i
      tick()
      onSelect(data[i].key)
    },
    onResponderRelease: () => {
      if (!drag.current.moved && drag.current.was) onSelect('all')
    },
  }

  return (
    <View onLayout={(e) => setW(e.nativeEvent.layout.width)}>
      <View style={[styles.badge, { backgroundColor: focus ? t.accentSoft : t.line }]}>
        <Text style={{ color: focus ? t.accent : t.text2, fontSize: 12, fontWeight: '600', fontFamily: rounded }}>
          {focus ? `${monthLabel(focus.key, true)} · ${money(focus.total)}` : 'Tap or drag across the bars'}
        </Text>
      </View>
      {w > 0 && (
        <View {...responder} style={{ marginTop: 8 }}>
          <Svg width={w} height={height} pointerEvents="none" accessible accessibilityRole="image"
            accessibilityLabel={`Monthly spending. ${data.map((d) => `${monthLabel(d.key, true)} ${money(d.total)}`).join(', ')}`}>
            <Defs>
              <LinearGradient id="barSel" x1="0" y1="0" x2="0" y2="1">
                <Stop offset="0" stopColor={t.cats[0]} stopOpacity="1" />
                <Stop offset="1" stopColor={t.cats[0]} stopOpacity="0.72" />
              </LinearGradient>
            </Defs>
            {ticks.map((v) => <Line key={v} x1={axisW} x2={w} y1={y(v)} y2={y(v)} stroke={t.line} strokeWidth={1} strokeDasharray={v === 0 ? undefined : '3 5'} />)}
            {ticks.map((v) => <SvgText key={`t${v}`} x={axisW - 8} y={y(v) + 4} fontSize={11} fill={t.text2} textAnchor="end">{moneyShort(v)}</SvgText>)}
            {data.map((d, i) => (
              <G key={d.key}>
                {selected === d.key && <Path d={`M${axisW + slot * i + 3},${topPad - 4} h${slot - 6} v${plotH + 4} h${-(slot - 6)} Z`} fill={t.accentSoft} fillOpacity={0.5} />}
                <Bar d={d} i={i} slot={slot} axisW={axisW} barW={barW} max={max || 1} y0={y0} plotH={plotH} topPad={topPad} fill={t.cats[0]}
                  dim={selected !== 'all' && selected !== d.key} picked={selected === d.key} />
              </G>
            ))}
            {data.map((d, i) => (
              <SvgText key={`l${d.key}`} x={axisW + slot * i + slot / 2} y={height - 6} fontSize={11} textAnchor="middle"
                fill={selected === d.key ? t.text : t.text2} fontWeight={selected === d.key ? '700' : '400'}>{d.label}</SvgText>
            ))}
          </Svg>
        </View>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  center: { position: 'absolute', inset: 0, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 46 },
  small: { fontSize: 12, marginTop: 2 },
  big: { fontSize: 21, fontWeight: '800', fontVariant: ['tabular-nums'] },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8, paddingHorizontal: 8, borderRadius: 16 },
  icon: { width: 40, height: 40, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  track: { height: 6, borderRadius: 3, overflow: 'hidden' },
  pct: { width: 36, textAlign: 'right', fontSize: 13, fontVariant: ['tabular-nums'] },
  badge: { alignSelf: 'flex-start', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 99 },
})
