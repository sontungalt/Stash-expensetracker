import { BlurView } from 'expo-blur'
import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect'
import { useEffect, useState } from 'react'
import { AccessibilityInfo, Platform, StyleSheet, View, useWindowDimensions } from 'react-native'
import Svg, { Defs, RadialGradient, Rect, Stop } from 'react-native-svg'
import { useTheme } from './theme'

const nativeGlass = Platform.OS === 'ios' && isGlassEffectAPIAvailable()

/** Honors Settings ▸ Accessibility ▸ Reduce Transparency by dropping to an opaque surface. */
function useReduceTransparency() {
  const [on, setOn] = useState(false)
  useEffect(() => {
    AccessibilityInfo.isReduceTransparencyEnabled().then(setOn).catch(() => {})
    const sub = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setOn)
    return () => sub.remove()
  }, [])
  return on
}

/**
 * Liquid Glass surface. Native `GlassView` on iOS 26+, blur + translucent fill elsewhere.
 * The glass fills the container behind the children (children are never inside the glass node).
 */
export function Glass({ radius = 22, tint, interactive = false, clear = false, frosted = false, style, children, ...rest }) {
  const t = useTheme()
  const opaque = useReduceTransparency()
  return (
    <View {...rest} style={[{ borderRadius: radius, overflow: 'hidden' }, style]}>
      {frosted && !opaque && (
        <>
          <BlurView intensity={90} tint={t.scheme === 'dark' ? 'systemChromeMaterialDark' : 'systemChromeMaterialLight'} style={StyleSheet.absoluteFill} />
          <View style={[StyleSheet.absoluteFill, { backgroundColor: t.scheme === 'dark' ? 'rgba(20,22,32,0.55)' : 'rgba(255,255,255,0.6)' }]} />
        </>
      )}
      {opaque ? (
        <View style={[StyleSheet.absoluteFill, { backgroundColor: t.card }]} />
      ) : nativeGlass ? (
        <GlassView style={StyleSheet.absoluteFill} glassEffectStyle={clear ? 'clear' : 'regular'} tintColor={tint} isInteractive={interactive} />
      ) : (
        <>
          <BlurView intensity={60} tint={t.scheme === 'dark' ? 'systemMaterialDark' : 'systemMaterialLight'} style={StyleSheet.absoluteFill} />
          {tint && <View style={[StyleSheet.absoluteFill, { backgroundColor: tint, opacity: 0.35 }]} />}
        </>
      )}
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { borderRadius: radius, borderWidth: StyleSheet.hairlineWidth, borderColor: t.glassEdge }]} />
      {children}
    </View>
  )
}

/** Soft color orbs behind the UI so the glass has something to refract. */
export function Backdrop() {
  const t = useTheme()
  const { width, height } = useWindowDimensions()
  const orbs = [
    { id: 'a', cx: width * 0.95, cy: height * 0.12, r: width * 0.95, c: t.orbs[0] },
    { id: 'b', cx: width * 0.02, cy: height * 0.45, r: width * 0.85, c: t.orbs[1] },
    { id: 'c', cx: width * 0.85, cy: height * 0.88, r: width * 0.95, c: t.orbs[2] },
  ]
  return (
    <View style={[StyleSheet.absoluteFill, { backgroundColor: t.bg }]} pointerEvents="none">
      <Svg width={width} height={height}>
        <Defs>
          {orbs.map((o) => (
            <RadialGradient key={o.id} id={`orb-${o.id}`} cx="50%" cy="50%" r="50%">
              <Stop offset="0" stopColor={o.c[0]} stopOpacity={o.c[1]} />
              <Stop offset="1" stopColor={o.c[0]} stopOpacity="0" />
            </RadialGradient>
          ))}
        </Defs>
        {orbs.map((o) => (
          <Rect key={o.id} x={o.cx - o.r} y={o.cy - o.r} width={o.r * 2} height={o.r * 2} fill={`url(#orb-${o.id})`} />
        ))}
      </Svg>
    </View>
  )
}
