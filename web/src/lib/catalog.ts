import { catalog } from '../generated/catalog'

export const allCategories = Array.from(new Set(catalog.map((l) => l.category))).sort()

export function filterLabs(labs: typeof catalog, query: string, category: string | null) {
  const q = query.trim().toLowerCase()
  return labs.filter((lab) => {
    if (category && lab.category !== category) return false
    if (!q) return true
    return (
      lab.name.toLowerCase().includes(q) ||
      (lab.code ?? '').toLowerCase().includes(q) ||
      lab.folder.toLowerCase().includes(q) ||
      (lab.description ?? '').toLowerCase().includes(q) ||
      lab.files.some((f) => f.name.toLowerCase().includes(q))
    )
  })
}

export function formatCode(code: string | null): string {
  return code ?? '—'
}
