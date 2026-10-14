import { createContext, useContext, useEffect, useRef, useState } from 'react'
import { AccessibilityInfo, Animated, Pressable } from 'react-native'

const MotionContext = createContext(true)
const AnimatedPressable = Animated.createAnimatedComponent(Pressable)
const SPRING = { stiffness: 380, damping: 21, mass: 0.7, useNativeDriver: true, isInteraction: false }

export function MotionProvider({ children }) {
  // Keep motion off until the device preference has been resolved.
  const [reduced, setReduced] = useState(true)
  useEffect(() => {
    let active = true
    let changed = false
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', (value) => {
      changed = true
      setReduced(value)
    })
    AccessibilityInfo.isReduceMotionEnabled().then((value) => {
      if (active && !changed) setReduced(value)
    }).catch(() => {})
    return () => { active = false; sub.remove() }
  }, [])
  return <MotionContext.Provider value={reduced}>{children}</MotionContext.Provider>
}

export const useReducedMotion = () => useContext(MotionContext)

/** Eased number tween (count-up counters, chart growth). `resetKey` restarts from 0 when it changes. */
export function useTween(target, dur = 700, resetKey = 0) {
  const reduced = useReducedMotion()
  const [v, setV] = useState(0)
  const cur = useRef(0)
  const lastKey = useRef(resetKey)
  useEffect(() => {
    if (reduced) {
      cur.current = target
      lastKey.current = resetKey
      const raf = requestAnimationFrame(() => setV(target))
      return () => cancelAnimationFrame(raf)
    }
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
  }, [target, dur, resetKey, reduced])
  return reduced ? target : v
}

/** Fade + spring into place, staggered by `delay`. */
export function FadeIn({ delay = 0, y = 14, scale = 0.96, style, children }) {
  const reduced = useReducedMotion()
  const [v] = useState(() => new Animated.Value(reduced ? 1 : 0))
  useEffect(() => {
    if (reduced) { v.setValue(1); return }
    const animation = Animated.spring(v, { toValue: 1, delay, ...SPRING })
    animation.start()
    return () => animation.stop()
  }, [v, delay, reduced])
  return (
    <Animated.View style={[style, { opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0, 1], extrapolate: 'clamp' }), transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [y, 0] }) }, { scale: v.interpolate({ inputRange: [0, 1], outputRange: [scale, 1] }) }] }]}>
      {children}
    </Animated.View>
  )
}

/** Pressable that springs down on touch. */
export function usePressScale(to = 0.96, selected = false, disabled = false) {
  const reduced = useReducedMotion()
  const [s] = useState(() => new Animated.Value(1))
  const previous = useRef(selected)
  useEffect(() => {
    const justSelected = selected && !previous.current
    previous.current = selected
    if (reduced || disabled) s.setValue(1)
    else {
      if (justSelected) s.setValue(1.06)
      Animated.spring(s, { toValue: 1, ...SPRING }).start()
    }
    return () => s.stopAnimation()
  }, [s, selected, reduced, disabled])
  const spring = (v) => {
    s.stopAnimation()
    if (reduced || disabled) { s.setValue(1); return }
    Animated.spring(s, { toValue: v, ...SPRING }).start()
  }
  return { style: { transform: [{ scale: s }] }, onPressIn: () => spring(to), onPressOut: () => spring(1) }
}

/** Animates the control itself, preserving layout, hit targets, and accessibility. */
export function PopPressable({ style, children, pressScale = 0.95, disabled, onPressIn, onPressOut, ...props }) {
  const [pressed, setPressed] = useState(false)
  const press = usePressScale(pressScale, props.accessibilityState?.selected, disabled)
  const state = { pressed: pressed && !disabled }
  return (
    <AnimatedPressable {...props} disabled={disabled}
      onPressIn={(event) => { setPressed(true); press.onPressIn(); onPressIn?.(event) }}
      onPressOut={(event) => { setPressed(false); press.onPressOut(); onPressOut?.(event) }}
      style={[typeof style === 'function' ? style(state) : style, press.style]}>
      {typeof children === 'function' ? children(state) : children}
    </AnimatedPressable>
  )
}
