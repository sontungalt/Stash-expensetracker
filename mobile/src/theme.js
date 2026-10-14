import { Platform, StyleSheet, useColorScheme } from 'react-native'
import { CATEGORIES, INCOME_CATEGORIES } from './lib'

// Categorical palette validated with the dataviz validator (adjacent CVD ΔE >= 8, normal-vision >= 19).
const catLight = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948']
const catDark = ['#3987e5', '#d95926', '#199e70', '#c98500', '#d55181', '#008300', '#9085e9', '#e66767']

export const alpha = (hex, a) => {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`
}

const light = {
  scheme: 'light', bg: '#eef1f8', glassEdge: 'rgba(255,255,255,0.75)', orbs: [['#4f8dff', 0.42], ['#b58cff', 0.28], ['#35d0a0', 0.26]], chip: 'rgba(255,255,255,0.55)', card: '#ffffff', border: 'rgba(20,30,60,0.06)', text: '#0d1020', text2: '#6a6f82', line: '#ebecf2',
  accent: '#2a78d6', accentSoft: 'rgba(42,120,214,0.14)', danger: '#d92d2b', good: '#0a7a2e', cats: catLight, onAccent: '#fff',
  hero: ['#0c2a63', '#1f5fc4', '#2a78d6'], shadow: '#1b2a4a', shadowOpacity: 0.09,
}
const dark = {
  scheme: 'dark', bg: '#07080d', glassEdge: 'rgba(255,255,255,0.14)', orbs: [['#2a6fdb', 0.5], ['#6a4cd8', 0.34], ['#16a37a', 0.26]], chip: 'rgba(255,255,255,0.07)', card: '#13141c', border: 'rgba(255,255,255,0.07)', text: '#ffffff', text2: '#9a9fb2', line: '#22242f',
  accent: '#3987e5', accentSoft: 'rgba(57,135,229,0.22)', danger: '#ff6b69', good: '#34d36b', cats: catDark, onAccent: '#fff',
  hero: ['#0b1d44', '#15407f', '#2262b8'], shadow: '#000', shadowOpacity: 0.5,
}

export const rounded = Platform.select({ ios: 'ui-rounded', default: undefined })

export const ICONS = { Food: '🍜', Transport: '🚇', Housing: '🏠', Shopping: '🛍️', Entertainment: '🎬', Health: '💊', Bills: '💡', Other: '✨', Allowance: '🎒', Salary: '💼', Gift: '🎁', Refund: '↩️' }

export function useTheme() {
  const t = useColorScheme() === 'dark' ? dark : light
  return {
    ...t,
    cat: (name) => (INCOME_CATEGORIES.includes(name) ? t.good : t.cats[Math.max(0, CATEGORIES.indexOf(name))]),
    card_: {
      backgroundColor: t.card, borderRadius: 24, borderWidth: StyleSheet.hairlineWidth, borderColor: t.border,
      shadowColor: t.shadow, shadowOpacity: t.shadowOpacity, shadowRadius: 20, shadowOffset: { width: 0, height: 8 },
    },
  }
}
