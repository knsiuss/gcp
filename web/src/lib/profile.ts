import type { Badge, ProfileData } from './types'

const PROFILE_PATH = './profile-data.json'

export function parseProfileId(input: string): string | null {
  const m = input.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i)
  if (m) return m[1].toLowerCase()
  if (/^[0-9a-f-]{20,}$/i.test(input.trim())) return input.trim().toLowerCase()
  return null
}

export async function fetchServerProfile(): Promise<ProfileData | null> {
  try {
    const res = await fetch(PROFILE_PATH, { cache: 'no-cache' })
    if (!res.ok) return null
    const data = (await res.json()) as ProfileData
    if (!Array.isArray(data.badges)) return null
    return data
  } catch {
    return null
  }
}

function parseProfileHtml(html: string, id: string): ProfileData {
  const doc = new DOMParser().parseFromString(html, 'text/html')
  const name = doc.querySelector('h1')?.textContent?.trim() ?? null

  const badges: Badge[] = []
  doc.querySelectorAll('.profile-badge').forEach((el) => {
    const title = el.querySelector('.ql-title-medium')
    const date = el.querySelector('.ql-body-medium')
    if (!title) return
    badges.push({
      name: title.textContent?.trim() ?? '',
      earnedAt: date ? date.textContent?.replace(/^Earned\s*/i, '').trim() ?? null : null,
    })
  })

  const league = doc.querySelector('.profile-league strong')
  const points = league ? parseInt(league.textContent?.replace(/[^\d]/g, '') || '', 10) || null : null

  return { id, name, points, badges, fetchedAt: new Date().toISOString() }
}

function parseProfileMarkdown(text: string, id: string): ProfileData {
  const nameMatch = text.match(/^Title:\s*(.+)$/m)
  const name = nameMatch ? nameMatch[1].trim() : null

  const badges: Badge[] = []
  const re = /badges\/\d+\)\s+(.+?)\s{2,}Earned\s+([^\n]+)/g
  let m
  while ((m = re.exec(text)) !== null) {
    badges.push({ name: m[1].trim(), earnedAt: m[2].trim() })
  }

  const league = text.match(/profile-league[\s\S]*?<strong>([\s\S]*?)<\/strong>/)
  const points = league ? parseInt(league[1].replace(/[^\d]/g, ''), 10) || null : null

  return { id, name, points, badges, fetchedAt: new Date().toISOString() }
}

const PROXIES = [
  (u: string) => `https://r.jina.ai/${u}`,
  (u: string) => `https://api.allorigins.win/raw?url=${encodeURIComponent(u)}`,
  (u: string) => `https://api.codetabs.com/v1/proxy?quest=${encodeURIComponent(u)}`,
]

export async function fetchProfileViaProxy(profileUrl: string, id: string): Promise<ProfileData> {
  let lastError: unknown = null
  for (const make of PROXIES) {
    try {
      const res = await fetch(make(profileUrl), { signal: AbortSignal.timeout(30000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const text = await res.text()
      const parsed =
        text.trimStart().startsWith('Title:') || text.includes('Earned ')
          ? parseProfileMarkdown(text, id)
          : parseProfileHtml(text, id)
      if (parsed.badges.length > 0 || parsed.name) return parsed
    } catch (e) {
      lastError = e
    }
  }
  throw new Error(
    lastError instanceof Error ? lastError.message : 'Failed to reach profile (CORS).',
  )
}
