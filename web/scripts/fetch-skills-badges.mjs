import { writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const WEB_ROOT = fileURLToPath(new URL('..', import.meta.url))
const OUT_DIR = join(WEB_ROOT, 'public')
const OUT_FILE = join(OUT_DIR, 'skills-badges.json')

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

async function fetchAllBadges() {
  const url = 'https://www.skills.google/catalog/list?skill-badge=skill-badge&per_page=100'
  const res = await fetch(url, {
    headers: { 'user-agent': UA, accept: 'application/json' },
    signal: AbortSignal.timeout(30000),
  })
  if (!res.ok) throw new Error(`Catalog HTTP ${res.status}`)
  const items = await res.json()
  if (!Array.isArray(items)) throw new Error('Unexpected catalog payload')

  return items
    .filter((it) => it && it.credentialType === 'skill_badge' && it.title)
    .map((it) => ({
      title: it.title,
      level: it.level ?? null,
      duration: it.duration ?? null,
      description: it.description ?? null,
      path: it.path ?? null,
    }))
    .sort((a, b) => a.title.localeCompare(b.title))
}

async function main() {
  const badges = await fetchAllBadges()
  if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true })
  const payload = { fetchedAt: new Date().toISOString(), badges }
  writeFileSync(OUT_FILE, JSON.stringify(payload, null, 2), 'utf8')
  console.log(`Fetched ${badges.length} skill badges from skills.google/catalog`)
  console.log(`Wrote ${OUT_FILE}`)
}

main().catch((e) => {
  console.error(e.message)
  process.exit(1)
})
