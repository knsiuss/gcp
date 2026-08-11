import { readdirSync, readFileSync, writeFileSync, existsSync, mkdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = fileURLToPath(new URL('../..', import.meta.url))
const OUT_DIR = fileURLToPath(new URL('../src/generated', import.meta.url))
const OUT_FILE = join(OUT_DIR, 'catalog.ts')
const IGNORE = new Set(['.git', '.claude', 'web', 'node_modules'])
const GIT_URL = 'https://github.com/knsiuss/gcp.git'
const SCRIPT_EXTS = new Set(['.sh', '.py', '.tf', '.yaml', '.yml', '.json'])
const CONFIG_NAMES = new Set(['Dockerfile', 'cloudbuild.yaml', 'cloudbuild.yml', 'variables.tf', 'main.tf'])

const FALLBACK = {
  'adk-gsp540': {
    name: 'Agent Development Kit (ADK) Challenge Lab',
    description: 'Python inspector, patcher, and solver scripts for the GSP540 ADK challenge lab.',
    category: 'GenAI',
  },
  'dms-mysql-gsp351': {
    name: 'Migrate MySQL Data to Cloud SQL Using DMS: Challenge Lab',
    description:
      'Automates creating the DMS source connection profile, the one-time migration job, the continuous migration job with VPC peering, testing replication, and promoting the destination.',
    category: 'Database',
  },
  'event-driven-messaging-arc113': {
    name: 'Event-Driven Messaging with Pub/Sub (ARC113)',
    description: 'Automates Pub/Sub topics, subscriptions, Cloud Functions, and event-driven resources for ARC113.',
    category: 'Application Integration',
  },
  'gcp-service-accounts-arc134': {
    name: 'Configure Service Accounts and IAM Roles (ARC134)',
    description: 'Automated solver for the Service Accounts and IAM Roles challenge lab.',
    category: 'IAM & Security',
  },
  'gcp-speech-ap-arc132': {
    name: 'Speech & Language Pre-trained APIs (ARC132)',
    description: 'Automated solver for implementing speech and language solutions with pre-trained APIs.',
    category: 'AI & ML',
  },
  'gdm-train-slm': {
    name: 'Google DeepMind: Train a Small Language Model (GSP531)',
    description: 'Complete Python automated solver for the Train a Small Language Model challenge lab.',
    category: 'GenAI',
  },
  'gemini-explorer-gsp515': {
    name: 'Gemini Explorer Challenge (GSP515)',
    description: 'Notebook fixer/update scripts for the Gemini Explorer challenge lab notebook.',
    category: 'GenAI',
  },
  'gmp-prometheus-gsp364': {
    name: 'Google Cloud Managed Service for Prometheus (GSP364)',
    description: 'Automates monitoring environments with Google Cloud Managed Service for Prometheus.',
    category: 'Observability',
  },
  'gmp-exporters-gsp1026': {
    name: 'Collect Metrics from Exporters (GSP1026)',
    description: 'Deploys a GKE cluster, example app, PodMonitoring, and runs GMP prometheus binary + node exporter with config.yaml (asks for the zone).',
    category: 'Observability',
  },
  'gsp514-build-data-mesh-knowledge-catalog': {
    name: 'Build a Data Mesh with Knowledge Catalog (GSP514)',
    description: 'Automated solver for the Build a Data Mesh with Knowledge Catalog challenge lab.',
    category: 'Data',
  },
  'gsp527-gemini': {
    name: 'Kickstarting Application Development with Gemini (GSP527)',
    description: 'Solver and fix scripts for Tasks 3 & 5 of the Gemini Code Assist challenge lab.',
    category: 'GenAI',
  },
  'gsp532-mcp': {
    name: 'MCP Server & Agent Deployments (GSP532)',
    description: 'Complete fixer for IAM, local MCP, ADK agent, and Cloud Run deployments in GSP532.',
    category: 'GenAI',
  },
  'ncc-gsp528': {
    name: 'Connecting Cloud Networks with NCC (GSP528)',
    description: 'Automated solution for the Network Connectivity Center challenge lab.',
    category: 'Networking',
  },
  'nl-api-gsp097': {
    name: 'Cloud Natural Language API: Qwik Start (GSP097)',
    description: 'Creates a Natural Language service account + API key and runs an entity analysis request.',
    category: 'AI & ML',
  },
  'nl-docs-gsp126': {
    name: 'Using the Natural Language API from Google Docs (GSP126)',
    description: 'Enables the Natural Language API, creates a restricted API key, and provides the complete Apps Script (code.gs) for sentiment highlighting in Google Docs.',
    category: 'AI & ML',
  },
  'secure-datalake-arc119': {
    name: 'Secure Data Lake (ARC119)',
    description: 'Automates secure data lake configuration with service accounts, KMS, and access controls.',
    category: 'Security',
  },
  'speech-language-arc114': {
    name: 'Speech & Language APIs (ARC114)',
    description: 'Automates enabling and using Speech-to-Text and Natural Language APIs.',
    category: 'AI & ML',
  },
}

function inferCategory(folder) {
  if (FALLBACK[folder]) return FALLBACK[folder].category
  if (folder.startsWith('bq-')) return 'BigQuery'
  if (folder.startsWith('gke-')) return 'Kubernetes / GKE'
  if (folder.startsWith('scc-')) return 'Security Command Center'
  if (folder === 'terraform-challenge') return 'Terraform'
  if (folder.startsWith('secure') || folder.startsWith('binary') || folder.startsWith('securing')) return 'Security'
  return 'Other'
}

function extractTitleFromReadme(readmePath) {
  try {
    const raw = readFileSync(readmePath, 'utf8')
    const firstLine = raw.split('\n').find((l) => l.trim().startsWith('#'))
    if (firstLine) return firstLine.replace(/^#+\s*/, '').trim()
  } catch {
    /* ignore */
  }
  return null
}

function extractCode(name, folder, readmeTitle) {
  const fromFolder = (folder.match(/(gsp|arc)-?(\d+)/i) || [])[0]
  const fromTitle = (readmeTitle || name).match(/\((GSP\d+|ARC\d+)\)/i)
  const fromName = (name.match(/\((GSP\d+|ARC\d+)\)/i) || [])[0]
  const raw = fromFolder || (fromName && fromName.replace(/[()]/g, '')) || (fromTitle && fromTitle[1])
  if (!raw) return null
  const m = raw.match(/(GSP|ARC)-?(\d+)/i)
  if (!m) return raw.toUpperCase()
  return `${m[1].toUpperCase()}${m[2]}`
}

function extractDescription(readmePath) {
  try {
    const raw = readFileSync(readmePath, 'utf8')
    const lines = raw.split('\n').map((l) => l.trim())
    const h1Index = lines.findIndex((l) => l.startsWith('#'))
    for (let i = h1Index + 1; i < lines.length; i++) {
      const line = lines[i]
      if (!line || line.startsWith('#') || line.startsWith('---') || line.startsWith('```')) continue
      if (/^[-*]\s/.test(line)) continue
      const cleaned = line
        .replace(/^#+\s*/, '')
        .replace(/\*\*/g, '')
        .replace(/`/g, '')
        .trim()
      if (cleaned.length > 20) return cleaned
    }
  } catch {
    /* ignore */
  }
  return null
}

function extractVariables(files) {
  const vars = new Map()
  for (const f of files) {
    const re = /read\s+-[a-zA-Z]+(\s+-p)?\s+"([^"]+)"/g
    let m
    while ((m = re.exec(f.content)) !== null) {
      const prompt = m[2].replace(/\[Default[^\]]*\]/i, '').replace(/\s*:\s*$/, '').trim()
      if (!vars.has(prompt)) vars.set(prompt, { prompt, files: [] })
      vars.get(prompt).files.push(f.name)
    }
  }
  return [...vars.values()]
}

function pickPrimary(files) {
  const priority = (f) => {
    if (/^(solve|setup)/i.test(f.name)) return 0
    if (/\.sh$/.test(f.name)) return 1
    if (/\.py$/.test(f.name)) return 2
    return 3
  }
  return [...files].sort((a, b) => priority(a) - priority(b))[0] || null
}

function readmeContent(readmePath) {
  try {
    return readFileSync(readmePath, 'utf8')
  } catch {
    return null
  }
}

function collectFiles(folderPath) {
  const out = []
  for (const entry of readdirSync(folderPath)) {
    const full = join(folderPath, entry)
    if (statSync(full).isDirectory()) continue
    const ext = extnameSafe(entry)
    const isScript = SCRIPT_EXTS.has(ext) && !entry.endsWith('.ipynb')
    const isConfig = CONFIG_NAMES.has(entry)
    if (!isScript && !isConfig) continue
    const content = readFileSync(full, 'utf8')
    const kind = entry.endsWith('.sh') || entry.endsWith('.py') ? 'script' : 'config'
    out.push({ name: entry, kind, content })
  }
  return out.sort((a, b) => {
    const rank = (f) => (/^(solve|setup)/i.test(f.name) ? 0 : 1)
    return rank(a) - rank(b) || a.name.localeCompare(b.name)
  })
}

function extnameSafe(file) {
  const i = file.lastIndexOf('.')
  return i === -1 ? '' : file.slice(i)
}

function build() {
  const dirs = readdirSync(ROOT)
    .filter((d) => {
      if (IGNORE.has(d)) return false
      return statSync(join(ROOT, d)).isDirectory()
    })
    .sort()

  const labs = []

  for (const folder of dirs) {
    const folderPath = join(ROOT, folder)
    const files = collectFiles(folderPath)
    if (files.length === 0) continue

    const readmePath = join(folderPath, 'README.md')
    const readmeTitle = extractTitleFromReadme(readmePath)
    const fallback = FALLBACK[folder] || {}
    const name = fallback.name || readmeTitle || folder
    const code = extractCode(name, folder, readmeTitle)
    const description = fallback.description || extractDescription(readmePath) || null
    const category = inferCategory(folder)
    const primary = pickPrimary(files)
    const runCommands = [
      `git clone ${GIT_URL} gcp-labs`,
      `cd gcp-labs/${folder}`,
      `chmod +x ${primary.name}`,
      `./${primary.name}`,
    ]
    const readme = readmeContent(readmePath)

    labs.push({
      id: folder,
      folder,
      name,
      code,
      category,
      description,
      variables: extractVariables(files),
      files: files.map((f) => ({ name: f.name, kind: f.kind, content: f.content })),
      primaryFile: primary.name,
      runCommands,
      readme,
    })
  }

  const generatedAt = new Date().toISOString()
  const json = JSON.stringify(labs, null, 2)

  const header = `// AUTO-GENERATED by scripts/generate-catalog.mjs — do not edit by hand.\n// Run: npm run generate\n// Generated: ${generatedAt}\n\nimport type { Lab } from '../lib/types'\n\nexport const generatedAt = ${JSON.stringify(generatedAt)}\n\nexport const catalog: Lab[] = ${json}\n`

  if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true })
  writeFileSync(OUT_FILE, header, 'utf8')
  console.log(`Wrote ${OUT_FILE}`)
  console.log(`Labs: ${labs.length}, total script bytes: ${labs.reduce((n, l) => n + l.files.reduce((m, f) => m + f.content.length, 0), 0)}`)
}

build()
