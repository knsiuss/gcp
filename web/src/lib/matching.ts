import type { Badge, Lab } from './types'

const ALIASES: Record<string, string[]> = {
  'adk-gsp540': ['agent development kit'],
  'binary-authorization': ['binary authorization'],
  'bq-data-sharing-gsp375': ['share data using google data cloud', 'google data cloud'],
  'bq-data-warehouse-challenge': ['build a data warehouse with bigquery', 'data warehouse with bigquery'],
  'bq-datamesh-gsp514': ['data mesh'],
  'bq-insights-challenge-gsp787': ['derive insights from bigquery'],
  'bq-join-pitfalls': ['data join pitfalls'],
  'bq-json-arrays-structs': ['json arrays and structs', 'arrays and structs'],
  'bq-partition-tables': ['date-partitioned tables', 'partitioned tables'],
  'bq-sql-cloudsql-gsp281': ['sql for bigquery and cloud sql'],
  'dms-mysql-gsp351': ['migrate mysql data to cloud sql', 'database migration service'],
  'event-driven-messaging-arc113': ['event-driven messaging'],
  'gcp-service-accounts-arc134': ['service accounts and iam'],
  'gcp-speech-ap-arc132': ['speech and language solutions'],
  'gdm-train-slm': ['train a small language model'],
  'gemini-explorer-gsp515': ['gemini explorer'],
  'gke-autoscaling-strategies': ['gke autoscaling strategies'],
  'gke-cost-optimization-challenge': ['optimize costs for google kubernetes engine'],
  'gke-cost-optimization-vms': ['cost-optimization for gke virtual machines'],
  'gke-manage-kubernetes-gsp510': ['manage kubernetes in google cloud'],
  'gke-multi-tenant-namespaces': ['multi-tenant cluster with namespaces'],
  'gmp-prometheus-gsp364': ['managed service for prometheus', 'monitoring in google cloud'],
  'gsp514-build-data-mesh-knowledge-catalog': ['knowledge catalog'],
  'gsp527-gemini': ['gemini code assist'],
  'gsp532-mcp': ['mcp server'],
  'monitor-log-observability': ['monitor and log with google cloud observability', 'google cloud observability'],
  'ncc-gsp528': ['network connectivity center'],
  'scc-findings-analysis': ['analyze findings with security command center'],
  'scc-get-started': ['get started with security command center'],
  'scc-mitigation': ['mitigate threats and vulnerabilities'],
  'scc-threat-detection': ['detect and investigate threats with security command center'],
  'secure-builds-cloudbuild': ['secure builds with cloud build'],
  'secure-datalake-arc119': ['secure data lake'],
  'secure-software-delivery': ['secure software delivery'],
  'securing-container-builds': ['securing container builds'],
  'speech-language-arc114': ['analyze speech and language with google apis'],
  'terraform-challenge': ['build infrastructure with terraform'],
}

export function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function folderAliases(lab: Lab): string[] {
  const clean = lab.folder
    .replace(/^[a-z]+-/, '')
    .replace(/-(gsp|arc)\d+$/i, '')
    .replace(/[_-]+/g, ' ')
  if (clean.length < 12) return []
  return [clean]
}

export function labAliases(lab: Lab): string[] {
  const curated = ALIASES[lab.id] ?? []
  return [...new Set([...curated, ...folderAliases(lab)])]
}

function scoreAlias(normalizedBadge: string, alias: string): number {
  const na = normalize(alias)
  if (!na) return 0
  if (normalizedBadge === na) return 1000
  if (normalizedBadge.includes(na)) return 500 + na.length
  if (na.length >= 10 && na.includes(normalizedBadge)) return 200 + normalizedBadge.length
  return 0
}

export interface MatchResult {
  badgeName: string
  earnedAt: string | null
  via: string
}

export function matchBadgesToLabs(badges: Badge[], labs: Lab[]): Map<string, MatchResult> {
  const result = new Map<string, MatchResult>()

  const pairs: { lab: Lab; badge: Badge; score: number; via: string }[] = []
  for (const badge of badges) {
    const nb = normalize(badge.name)
    if (!nb) continue
    for (const lab of labs) {
      let best = 0
      let via = ''
      for (const alias of labAliases(lab)) {
        const s = scoreAlias(nb, alias)
        if (s > best) {
          best = s
          via = alias
        }
      }
      if (best >= 8) pairs.push({ lab, badge, score: best, via })
    }
  }

  pairs.sort((a, b) => b.score - a.score)

  const usedBadges = new Set<string>()
  for (const p of pairs) {
    if (result.has(p.lab.id)) continue
    if (usedBadges.has(p.badge.name)) continue
    usedBadges.add(p.badge.name)
    result.set(p.lab.id, { badgeName: p.badge.name, earnedAt: p.badge.earnedAt, via: p.via })
  }

  return result
}

export function parseBadgeDate(earnedAt: string | null): Date | null {
  if (!earnedAt) return null
  const cleaned = earnedAt.replace(/\s+(UTC|GMT|[A-Z]{3,4})\s*$/i, '').trim()
  const d = new Date(cleaned)
  return Number.isNaN(d.getTime()) ? null : d
}
