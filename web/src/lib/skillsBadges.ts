export interface SkillsBadge {
  title: string
  level: string | null
  duration: string | null
  description: string | null
  path: string | null
}

export interface SkillsBadgesFile {
  fetchedAt: string
  badges: SkillsBadge[]
}

const PATH = './skills-badges.json'

export async function fetchSkillsBadges(): Promise<SkillsBadgesFile | null> {
  try {
    const res = await fetch(PATH, { cache: 'no-cache' })
    if (!res.ok) return null
    const data = (await res.json()) as SkillsBadgesFile
    if (!Array.isArray(data.badges)) return null
    return data
  } catch {
    return null
  }
}

export function normalizeBadgeTitle(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function isBadgeEarned(badge: SkillsBadge, earnedNames: Set<string>): boolean {
  const title = normalizeBadgeTitle(badge.title)
  for (const name of earnedNames) {
    if (normalizeBadgeTitle(name) === title) return true
  }
  return false
}
