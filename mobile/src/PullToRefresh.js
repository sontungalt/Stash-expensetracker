import { useCallback, useEffect, useRef, useState } from 'react'
import { ActivityIndicator, Animated, StyleSheet, Text, View } from 'react-native'
import * as Haptics from 'expo-haptics'
import { Glass } from './Glass'
import { useTheme } from './theme'

/*
 * Pull-to-refresh (React Native port of easyui PullToRefresh).
 * Status machine: idle → pulling → ready (past `threshold`) → refreshing → complete.
 * The indicator follows the (damped) pull with opacity + scale ramps, the chevron flips at the
 * threshold, and on release it stays pinned while refreshing, then confirms with "Updated".
 * iOS already rubber-bands the scroll view, so the damping curve is native; we only read the offset.
 */
const wait = (ms) => new Promise((r) => setTimeout(r, ms))
const LABEL = { idle: 'Pull to refresh', pulling: 'Pull to refresh', ready: 'Release to refresh', refreshing: 'Refreshing…', complete: 'Updated' }
const SPRING = { stiffness: 300, damping: 26, useNativeDriver: true }

export function usePullToRefresh(onRefresh, { threshold = 68, maxPull = 110 } = {}) {
  const [status, setStatus] = useState('idle')
  const st = useRef('idle')
  const [y] = useState(() => new Animated.Value(0))
  const [pin] = useState(() => new Animated.Value(0)) // 0 = follow the pull, 1 = pinned while refreshing

  const set = useCallback((s) => { st.current = s; setStatus(s) }, [])

  const [onScroll] = useState(() => Animated.event([{ nativeEvent: { contentOffset: { y } } }], { useNativeDriver: true }))
  useEffect(() => {
    const id = y.addListener(({ value }) => {
      if (st.current === 'refreshing' || st.current === 'complete') return
      const d = -value
      const next = d >= threshold ? 'ready' : d > 6 ? 'pulling' : 'idle'
      if (next === st.current) return
      if (next === 'ready') Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {})
      set(next)
    })
    return () => y.removeListener(id)
  }, [y, threshold, set])

  const onScrollEndDrag = useCallback(async () => {
    if (st.current !== 'ready') return
    set('refreshing')
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {})
    Animated.spring(pin, { toValue: 1, ...SPRING }).start()
    try { await Promise.all([onRefresh?.(), wait(900)]) } catch { /* keep the UI responsive even if refresh fails */ }
    set('complete')
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {})
    await wait(750)
    Animated.spring(pin, { toValue: 0, ...SPRING }).start()
    set('idle')
  }, [onRefresh, pin, set])

  const scrollProps = { onScroll, onScrollEndDrag, scrollEventThrottle: 16, alwaysBounceVertical: true }
  const indicator = <PullIndicator status={status} y={y} pin={pin} threshold={threshold} maxPull={maxPull} />
  return { scrollProps, indicator, status }
}

export function PullIndicator({ status, y, pin, threshold, maxPull }) {
  const t = useTheme()
  const [flip] = useState(() => new Animated.Value(0))
  const ready = status === 'ready'
  useEffect(() => { Animated.spring(flip, { toValue: ready ? 1 : 0, stiffness: 420, damping: 30, useNativeDriver: true }).start() }, [ready, flip])

  // follow the pull (log-ish: ~0.55 of the finger distance, capped by maxPull)
  const pullY = y.interpolate({ inputRange: [-maxPull * 2, -threshold, 0, 1], outputRange: [maxPull * 0.72, threshold * 0.6, -26, -26], extrapolate: 'clamp' })
  const pinY = pin.interpolate({ inputRange: [0, 1], outputRange: [0, threshold * 0.6 + 26] })
  const pullOpacity = y.interpolate({ inputRange: [-threshold, -threshold * 0.3, 0], outputRange: [1, 0.7, 0], extrapolate: 'clamp' })
  const pullScale = y.interpolate({ inputRange: [-threshold, 0], outputRange: [1, 0.75], extrapolate: 'clamp' })
  const opacity = Animated.add(pullOpacity, pin)
  const scale = Animated.add(pullScale, pin.interpolate({ inputRange: [0, 1], outputRange: [0, 0.25] }))

  return (
    <Animated.View pointerEvents="none" style={[styles.wrap, { opacity, transform: [{ translateY: Animated.add(pullY, pinY) }, { scale }] }]}
      accessible={status === 'refreshing' || status === 'complete'} accessibilityLiveRegion="polite" accessibilityLabel={LABEL[status]}>
      <Glass radius={22} frosted style={styles.pill}>
        <View style={styles.inner}>
          {status === 'refreshing' ? <ActivityIndicator size="small" color={t.accent} />
            : status === 'complete' ? <Text style={{ color: t.good, fontSize: 16, fontWeight: '800' }}>✓</Text>
            : <Animated.Text style={{ color: t.accent, fontSize: 15, fontWeight: '800', transform: [{ rotate: flip.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '180deg'] }) }] }}>↓</Animated.Text>}
          <Text style={{ color: t.text, fontSize: 14, fontWeight: '700' }}>{LABEL[status]}</Text>
        </View>
      </Glass>
    </Animated.View>
  )
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', top: 0, left: 0, right: 0, alignItems: 'center', zIndex: 5 },
  pill: { height: 44 },
  inner: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 9, paddingHorizontal: 18 },
})
