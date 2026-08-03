import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const WEB_ROOT = fileURLToPath(new URL('..', import.meta.url))
const SOURCE_FILE = join(WEB_ROOT, 'public', 'profile-source.json')
const OUT_FILE = join(WEB_ROOT, 'public', 'profile-data.json')

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

function normalizeProfileId(input) {
  if (!input) return null
  const trimmed = input.trim()
  const m = trimmed.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i)
  if (m) return m[1].toLowerCase()
  if (/^[0-9a-f-]{20,}$/i.test(trimmed)) return trimmed.toLowerCase()
  return null
}

function stripTags(html) {
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim()
}

function parseProfile(html, profileId) {
  if (html.trimStart().startsWith('Title:') || html.includes('Earned ')) {
    return parseProfileMarkdown(html, profileId)
  }
  const nameMatch = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/)
  const name = nameMatch ? stripTags(nameMatch[1]) : null

  const badges = []
  const blockRe = /<div class=['"]profile-badge['"][\s\S]*?<\/div>/g
  let block
  while ((block = blockRe.exec(html)) !== null) {
    const nameM = block[0].match(/<span class=['"][^'"]*ql-title-medium[^'"]*['"][^>]*>([\s\S]*?)<\/span>/)
    const dateM = block[0].match(/<span class=['"][^'"]*ql-body-medium[^'"]*['"][^>]*>([\s\S]*?)<\/span>/)
    if (!nameM) continue
    badges.push({
      name: stripTags(nameM[1]),
      earnedAt: dateM ? stripTags(dateM[1]).replace(/^Earned\s*/i, '') : null,
    })
  }

  const pointsM = html.match(/profile-league[\s\S]*?<strong>([\s\S]*?)<\/strong>/)
  const points = pointsM ? parseInt(stripTags(pointsM[1]).replace(/[^\d]/g, ''), 10) || null : null

  return { id: profileId, name, points, badges }
}

function parseProfileMarkdown(text, profileId) {
  const nameMatch = text.match(/^Title:\s*(.+)$/m)
  const name = nameMatch ? nameMatch[1].trim() : null

  const badges = []
  const re = /badges\/\d+\)\s+(.+?)\s{2,}Earned\s+([^\n]+)/g
  let m
  while ((m = re.exec(text)) !== null) {
    badges.push({ name: m[1].trim(), earnedAt: m[2].trim() })
  }

  const league = text.match(/profile-league[\s\S]*?<strong>([\s\S]*?)<\/strong>/)
  const points = league ? parseInt(league[1].replace(/[^\d]/g, ''), 10) || null : null

  return { id: profileId, name, points, badges }
}

async function fetchProfile(profileId) {
  const url = `https://www.cloudskillsboost.google/public_profiles/${profileId}`
  try {
    const res = await fetch(url, { headers: { 'user-agent': UA, accept: 'text/html' } })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const html = await res.text()
    return parseProfile(html, profileId)
  } catch (err) {
    console.log(`Direct fetch failed (${err.message}), falling back to reader proxy…`)
    const res = await fetch(`https://r.jina.ai/${url}`)
    if (!res.ok) throw new Error(`Reader proxy HTTP ${res.status}`)
    const text = await res.text()
    return parseProfileMarkdown(text, profileId)
  }
}

function readSource() {
  if (!existsSync(SOURCE_FILE)) return null
  try {
    return JSON.parse(readFileSync(SOURCE_FILE, 'utf8'))
  } catch {
    return null
  }
}

async function main() {
  const args = process.argv.slice(2)
  const fromArg = normalizeProfileId(args[0])
  const fromFile = readSource()
  const fromEnv = process.env.ARCADE_PROFILE_ID
  const profileId = fromArg || normalizeProfileId(fromFile?.profileUrl || fromFile?.profileId) || normalizeProfileId(fromEnv)

  if (!profileId) {
    console.log('No profile configured. Set web/public/profile-source.json or ARCADE_PROFILE_ID.')
    process.exit(0)
  }

  const data = await fetchProfile(profileId)
  data.fetchedAt = new Date().toISOString()
  writeFileSync(OUT_FILE, JSON.stringify(data, null, 2), 'utf8')
  console.log(`Profile ${profileId}: ${data.name} — ${data.badges.length} badges, points=${data.points ?? 'n/a'}`)
  console.log(`Wrote ${OUT_FILE}`)
}

main().catch((e) => {
  console.error(e.message)
  process.exit(1)
})
