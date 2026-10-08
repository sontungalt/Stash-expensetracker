import { useCallback, useEffect, useRef, useState } from 'react'
import { Animated, Dimensions, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native'
import * as Haptics from 'expo-haptics'
import { Glass } from './Glass'
import { alpha, useTheme } from './theme'

/*
 * Origin-aware dropdown (React Native port of easyui OriginDropdown).
 * The menu doesn't just appear: it grows from the trigger's own edge (scale .96 → 1, an 8pt
 * outward → inward slide, snappy spring), and the chevron flips 180°.
 */
const OFFSET = { top: { x: 0, y: 8 }, bottom: { x: 0, y: -8 } }
const SPRING = { stiffness: 420, damping: 30, mass: 0.8, useNativeDriver: true }

export function Chevron({ open, color }) {
  const [r] = useState(() => new Animated.Value(open ? 1 : 0))
  useEffect(() => { Animated.spring(r, { toValue: open ? 1 : 0, ...SPRING }).start() }, [open, r])
  return (
    <Animated.Text style={{ color, fontSize: 11, fontWeight: '800', transform: [{ rotate: r.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '180deg'] }) }] }}>
      ▼
    </Animated.Text>
  )
}

/**
 * @param {{
 *  trigger: (state: { open: boolean }) => React.ReactNode,
 *  items: { id: string, label: string, description?: string, icon?: string, selected?: boolean, destructive?: boolean, disabled?: boolean, onSelect?: () => void }[],
 *  side?: 'top' | 'bottom', align?: 'start' | 'end', minWidth?: number, label?: string
 * }} props
 */
export default function OriginDropdown({ trigger, items, side = 'bottom', align = 'end', minWidth = 220, label }) {
  const t = useTheme()
  const ref = useRef(null)
  const [open, setOpen] = useState(false)
  const [mounted, setMounted] = useState(false)
  const [anchor, setAnchor] = useState({ x: 0, y: 0, w: 0, h: 0 })
  const [v] = useState(() => new Animated.Value(0))
  const off = OFFSET[side]

  const show = useCallback(() => {
    ref.current?.measureInWindow((x, y, w, h) => {
      Haptics.selectionAsync().catch(() => {})
      setAnchor({ x, y, w, h })
      setMounted(true)
      setOpen(true)
    })
  }, [])
  const hide = useCallback((after) => {
    setOpen(false)
    Animated.timing(v, { toValue: 0, duration: 120, useNativeDriver: true }).start(() => { setMounted(false); after?.() })
  }, [v])

  useEffect(() => {
    if (open) Animated.spring(v, { toValue: 1, ...SPRING }).start()
  }, [open, v])

  const { width: W, height: H } = Dimensions.get('window')
  const pos = { position: 'absolute', maxHeight: Math.min(360, H * 0.5) }
  if (align === 'end') pos.right = Math.max(12, W - (anchor.x + anchor.w))
  else pos.left = Math.max(12, anchor.x)
  if (side === 'bottom') pos.top = anchor.y + anchor.h + 8
  else pos.bottom = H - anchor.y + 8
  // the menu grows out of the corner nearest the trigger
  const origin = `${side === 'bottom' ? 'top' : 'bottom'} ${align === 'end' ? 'right' : 'left'}`

  return (
    <>
      <Pressable ref={ref} onPress={() => (open ? hide() : show())} collapsable={false} accessibilityRole="button" accessibilityLabel={label}
        accessibilityState={{ expanded: open }} accessibilityHint="Opens a menu">
        {trigger({ open })}
      </Pressable>

      <Modal visible={mounted} transparent animationType="none" onRequestClose={() => hide()} statusBarTranslucent>
        <Pressable style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.10)' }]} onPress={() => hide()} accessibilityLabel="Close menu" />
        <Animated.View
          style={[pos, { minWidth, opacity: v, transformOrigin: origin,
            transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.96, 1] }) }, { translateX: v.interpolate({ inputRange: [0, 1], outputRange: [off.x, 0] }) }, { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [off.y, 0] }) }] }]}
          accessibilityViewIsModal>
          <Glass radius={20} frosted style={styles.menu}>
            <ScrollView bounces={false} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingVertical: 6 }} accessibilityRole="menu">
              {items.map((it, i) => (
                <Pressable key={it.id} disabled={it.disabled} accessibilityRole="menuitem" accessibilityState={{ selected: !!it.selected, disabled: !!it.disabled }}
                  onPress={() => { Haptics.selectionAsync().catch(() => {}); hide(it.onSelect) }}
                  style={({ pressed }) => [styles.item, { backgroundColor: pressed ? t.accentSoft : it.selected ? alpha(t.accent, 0.1) : 'transparent', opacity: it.disabled ? 0.35 : 1 }]}>
                  {it.icon && <Text style={styles.icon}>{it.icon}</Text>}
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: it.destructive ? t.danger : t.text, fontSize: 16, fontWeight: it.selected ? '700' : '500' }}>{it.label}</Text>
                    {it.description && <Text style={{ color: t.text2, fontSize: 12.5, marginTop: 1 }}>{it.description}</Text>}
                  </View>
                  {it.selected && <Text style={{ color: t.accent, fontSize: 17, fontWeight: '800' }}>✓</Text>}
                </Pressable>
              ))}
            </ScrollView>
          </Glass>
        </Animated.View>
      </Modal>
    </>
  )
}

const styles = StyleSheet.create({
  menu: { shadowColor: '#000', shadowOpacity: 0.25, shadowRadius: 24, shadowOffset: { width: 0, height: 12 } },
  item: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 12, marginHorizontal: 6, borderRadius: 14 },
  icon: { fontSize: 18, width: 24, textAlign: 'center' },
})
