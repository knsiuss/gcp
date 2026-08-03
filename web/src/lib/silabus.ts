export interface SilabusGame {
  name: string
  url: string | null
  accessCode: string | null
  status: 'active' | 'closed' | 'coming-soon'
}

export interface SilabusBadge {
  title: string
  url: string | null
  labs: number | null
  credits: number | null
}

export interface SilabusLevel {
  level: 'beginner' | 'intermediate' | 'advanced' | 'other'
  title: string
  count: number | null
  badges: SilabusBadge[]
}

export interface SilabusFile {
  fetchedAt: string
  source: string
  intro: string[]
  games: SilabusGame[]
  levels: SilabusLevel[]
  totalBadges: number
}

const PATH = './silabus.json'

export async function fetchSilabus(): Promise<SilabusFile | null> {
  try {
    const res = await fetch(PATH, { cache: 'no-cache' })
    if (!res.ok) return null
    const data = (await res.json()) as SilabusFile
    if (!Array.isArray(data.levels)) return null
    return data
  } catch {
    return null
  }
}

export function courseTemplateId(url: string | null): string | null {
  if (!url) return null
  const m = url.match(/course_templates\/(\d+)/)
  return m ? m[1] : null
}

