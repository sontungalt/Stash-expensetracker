import { useEffect, useRef, useState } from 'react'
import { Animated, Easing } from 'react-native'

/** Eased number tween (count-up counters, chart growth). `resetKey` restarts from 0 when it changes. */
export function useTween(target, dur = 700, resetKey = 0) {
  const [v, setV] = useState(0)
  const cur = useRef(0)
  const lastKey = useRef(resetKey)
  useEffect(() => {
    if (lastKey.current !== resetKey) cur.current = 0
    lastKey.current = resetKey
    const start = cur.current
    const t0 = Date.now()
    let raf
    const step = () => {
      const p = Math.min(1, (Date.now() - t0) / dur)
      cur.current = start + (target - start) * (1 - Math.pow(1 - p, 4))
      setV(cur.current)
      if (p < 1) raf = requestAnimationFrame(step)
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [target, dur, resetKey])
  return v
}

/** Fade + rise on mount, staggered by `delay`. */
export function FadeIn({ delay = 0, y = 14, style, children }) {
  const [v] = useState(() => new Animated.Value(0))
  useEffect(() => {
    Animated.timing(v, { toValue: 1, duration: 420, delay, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start()
  }, [v, delay])
  return (
    <Animated.View style={[style, { opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [y, 0] }) }] }]}>
      {children}
    </Animated.View>
  )
}

/** Pressable that springs down on touch. */
export function usePressScale(to = 0.96) {
  const [s] = useState(() => new Animated.Value(1))
  const spring = (v) => Animated.spring(s, { toValue: v, useNativeDriver: true, speed: 40, bounciness: 6 }).start()
  return { style: { transform: [{ scale: s }] }, onPressIn: () => spring(to), onPressOut: () => spring(1) }
}
