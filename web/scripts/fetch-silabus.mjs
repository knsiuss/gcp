import { writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const WEB_ROOT = fileURLToPath(new URL('..', import.meta.url))
const OUT_DIR = join(WEB_ROOT, 'public')
const OUT_FILE = join(OUT_DIR, 'silabus.json')

const API =
  'https://rsvp.googleapis.com/v1/engagements/arcade-fasilitator-id:viewSite?key=AIzaSyBGi84vGDxT8DNTFFqIEF78hpwrvoTE7uM'
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

function decodeEntities(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&nbsp;/g, ' ')
    .replace(/&rarr;/g, '→')
}

function textOnly(html) {
  return decodeEntities(html)
    .replace(/<br\s*\/?>/g, '\n')
    .replace(/<\/(p|li|h1|h2|h3|h4|ul|ol)>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*\n+/g, '\n')
    .trim()
}

function extractComponents(blocks) {
  const items = []
  const walk = (node) => {
    if (!node) return
    if (node.textComponent) {
      items.push({ kind: 'text', text: node.textComponent.text })
    } else if (node.imageComponent) {
      const img = node.imageComponent.image ?? {}
      items.push({
        kind: 'image',
        uri: img.uri ?? '',
        linkUri: img.linkUri ?? '',
      })
    } else if (node.accordionComponent) {
      const acc = node.accordionComponent
      const entries = (acc.items ?? []).map((it) => ({
        title: it.title,
        html: it.text ?? '',
      }))
      items.push({ kind: 'accordion', title: acc.title ?? '', entries })
    } else {
      for (const v of Object.values(node)) {
        if (Array.isArray(v)) v.forEach(walk)
        else if (v && typeof v === 'object') walk(v)
      }
    }
  }
  for (const blk of blocks) walk(blk)
  return items
}

function parseBadgeList(html) {
  const clean = decodeEntities(html)
  const links = [...clean.matchAll(/<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g)]
  return links.map((m) => {
    const href = m[1]
    const title = m[2]
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/\s+/g, ' ')
      .trim()
    const after = clean.slice(m.index + m[0].length)
    const meta = after.match(/^\s*\(([^)]*)\)/)
    let labs = null
    let credits = null
    if (meta) {
      const labsM = meta[1].match(/(\d+)\s*labs?/i)
      const credM = meta[1].match(/(\d+)\s*credits?/i)
      if (labsM) labs = Number(labsM[1])
      if (credM) credits = Number(credM[1])
    }
    return { title, url: href, labs, credits }
  })
}

function parseGames(items) {
  const games = []
  const nameOrder = [
    'Arcade Adventure',
    'Arcade Voyage',
    'Arcade Trail',
    'Arcade Basecamp',
    'Arcade Special Game',
    'New Arcade Game (Coming Soon)',
  ]
  let idx = 0

  for (let i = 0; i < items.length; i++) {
    const item = items[i]
    if (item.kind !== 'image' || !item.linkUri) continue
    const name = nameOrder[idx]
    idx += 1
    if (!name) break

    let accessCode = null
    let status = 'active'
    for (let j = i + 1; j < items.length; j++) {
      const nxt = items[j]
      if (nxt.kind === 'image') break
      if (nxt.kind === 'text' && /Access code/i.test(nxt.text)) {
        const codeM = nxt.text.match(/>([^<]+)<\/a>/)
        if (/DITUTUP/i.test(nxt.text)) status = 'closed'
        else if (codeM) accessCode = codeM[1].trim()
        break
      }
    }
    if (/coming soon/i.test(name)) status = 'coming-soon'

    games.push({ name, url: item.linkUri, accessCode, status })
  }

  return games
}

function parseLevels(items) {
  const acc = items.find((i) => i.kind === 'accordion')
  if (!acc) return []
  return acc.entries
    .filter((e) => /^(Beginner|Intermediate|Advanced)/i.test(e.title))
    .map((e) => {
      const levelM = e.title.match(/^(Beginner|Intermediate|Advanced)/i)
      const countM = e.title.match(/(\d+)\s*Badge/i)
      return {
        level: levelM ? levelM[1].toLowerCase() : 'other',
        title: e.title,
        count: countM ? Number(countM[1]) : null,
        badges: parseBadgeList(e.html),
      }
    })
}

async function main() {
  const res = await fetch(API, {
    headers: { 'user-agent': UA, accept: 'application/json' },
    signal: AbortSignal.timeout(30000),
  })
  if (!res.ok) throw new Error(`RSVP API HTTP ${res.status}`)
  const data = await res.json()

  const page = (data.pages ?? []).find((p) => p.slug === 'silabus')
  if (!page) throw new Error('Silabus page not found in site payload')

  const items = extractComponents(page.blocks ?? [])
  const introBlocks = items.filter((i) => i.kind === 'text').map((i) => textOnly(i.text))
  const games = parseGames(items)
  const levels = parseLevels(items)

  const payload = {
    fetchedAt: new Date().toISOString(),
    source: 'https://rsvp.withgoogle.com/events/arcade-fasilitator-id/silabus',
    intro: introBlocks.filter(Boolean).slice(0, 3),
    games,
    levels,
    totalBadges: levels.reduce((sum, l) => sum + (l.badges?.length ?? 0), 0),
  }

  if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true })
  writeFileSync(OUT_FILE, JSON.stringify(payload, null, 2), 'utf8')
  console.log(`Fetched silabus: ${games.length} games, ${payload.totalBadges} badges in ${levels.length} levels`)
  console.log(`Wrote ${OUT_FILE}`)
}

main().catch((e) => {
  console.error(e.message)
  process.exit(1)
})
