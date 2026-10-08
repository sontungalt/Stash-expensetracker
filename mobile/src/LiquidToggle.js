import { useEffect, useRef, useState } from 'react'
import { AccessibilityInfo, Animated, Pressable, StyleSheet, Text, View } from 'react-native'
import Svg, { Defs, Path, RadialGradient, Stop } from 'react-native-svg'
import * as Haptics from 'expo-haptics'
import { Glass } from './Glass'
import { useTheme } from './theme'

/*
 * Liquid toggle (React Native port). The blob is one SVG path rebuilt every frame from a spring:
 * it stretches along the travel axis and wobbles mid-flight, then settles back into a circle.
 */
const POINTS = 12

export function buildBlobPath(width, height, t, stretch) {
  const pad = 4
  const baseR = (height - pad * 2) / 2
  const leftX = pad + baseR
  const rightX = width - pad - baseR
  const cy = height / 2
  const rx = baseR * (1 + stretch * 0.35)
  const ry = baseR * (1 - stretch * 0.12)
  const cx = leftX + (rightX - leftX) * t

  const pts = []
  for (let i = 0; i < POINTS; i++) {
    const a = (Math.PI * 2 * i) / POINTS - Math.PI / 2
    const wob = 1 + stretch * 0.18 * Math.sin(a * 3 + t * Math.PI * 2)
    pts.push([cx + Math.cos(a) * rx * wob, cy + Math.sin(a) * ry * wob])
  }
  const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]
  const s = mid(pts[POINTS - 1], pts[0])
  let d = `M ${s[0].toFixed(2)} ${s[1].toFixed(2)}`
  for (let i = 0; i < POINTS; i++) {
    const c = pts[i]
    const e = mid(c, pts[(i + 1) % POINTS])
    d += ` Q ${c[0].toFixed(2)} ${c[1].toFixed(2)} ${e[0].toFixed(2)} ${e[1].toFixed(2)}`
  }
  return `${d} Z`
}

const hex = (h) => { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
const mix = (a, b, k) => { const A = hex(a), B = hex(b); return `rgb(${A.map((v, i) => Math.round(v + (B[i] - v) * k)).join(',')})` }

let uid = 0

export default function LiquidToggle({ value, onChange, label, width = 60, height = 34, showLabels = true }) {
  const t = useTheme()
  const [id] = useState(() => `lt${uid++}`)
  const [progress] = useState(() => new Animated.Value(value ? 1 : 0))
  const [p, setP] = useState(value ? 1 : 0)
  const reduce = useRef(false)

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then((v) => { reduce.current = v }).catch(() => {})
    const sub = progress.addListener(({ value: v }) => setP(v))
    return () => progress.removeListener(sub)
  }, [progress])

  useEffect(() => {
    if (reduce.current) { progress.setValue(value ? 1 : 0); return }
    Animated.spring(progress, { toValue: value ? 1 : 0, stiffness: 280, damping: 24, mass: 0.55, useNativeDriver: false }).start()
  }, [value, progress])

  const tc = Math.min(1, Math.max(0, p))
  const stretch = Math.max(0, 4 * tc * (1 - tc))
  const blob = mix(t.scheme === 'dark' ? '#c9ccd8' : '#9aa1b8', t.accent, tc)

  return (
    <Pressable onPress={() => { Haptics.selectionAsync().catch(() => {}); onChange(!value) }} hitSlop={10}
      accessibilityRole="switch" accessibilityState={{ checked: value }} accessibilityLabel={label}>
      <Glass radius={height / 2} interactive style={{ width, height }}>
        {showLabels && (
          <View style={[StyleSheet.absoluteFill, styles.labels]} pointerEvents="none">
            <Text style={[styles.lbl, { color: t.accent, opacity: tc }]}>ON</Text>
            <Text style={[styles.lbl, { color: t.text2, opacity: 0.8 * (1 - tc) }]}>OFF</Text>
          </View>
        )}
        <Svg width={width} height={height} style={StyleSheet.absoluteFill} pointerEvents="none">
          <Defs>
            <RadialGradient id={id} cx="35%" cy="35%" r="85%">
              <Stop offset="0" stopColor={blob} stopOpacity="1" />
              <Stop offset="1" stopColor={blob} stopOpacity="0.78" />
            </RadialGradient>
          </Defs>
          <Path d={buildBlobPath(width, height, p, stretch)} fill={`url(#${id})`} />
        </Svg>
      </Glass>
    </Pressable>
  )
}

const styles = StyleSheet.create({
  labels: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 10 },
  lbl: { fontSize: 9.5, fontWeight: '800', letterSpacing: 0.3 },
})
