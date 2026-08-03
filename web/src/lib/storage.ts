const KEYS = {
  profile: 'arcade.profile',
  profileUrl: 'arcade.profileUrl',
  overrides: 'arcade.overrides',
  targets: 'arcade.targets',
} as const

export function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    if (raw == null) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function save(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* ignore quota errors */
  }
}

export { KEYS }
