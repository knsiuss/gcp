import type { Lab, StatusFilter } from '../lib/types'
import { formatCode } from '../lib/catalog'

interface LabListProps {
  labs: Lab[]
  total: number
  categories: string[]
  query: string
  category: string | null
  status: StatusFilter
  selectedId: string | null
  doneIds: Set<string>
  onQueryChange: (q: string) => void
  onCategoryChange: (c: string | null) => void
  onStatusChange: (s: StatusFilter) => void
  onSelect: (id: string) => void
}

export function LabList(props: LabListProps) {
  const { labs, total, categories, query, category, status, selectedId, doneIds } = props

  return (
    <div className="lab-pane">
      <div className="lab-toolbar">
        <div className="search">
          <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
          <input
            type="text"
            value={query}
            onChange={(e) => props.onQueryChange(e.target.value)}
            placeholder="Search labs"
            aria-label="Search labs"
          />
        </div>

        <div className="cats">
          <button
            className={`pill${category === null ? ' active' : ''}`}
            onClick={() => props.onCategoryChange(null)}
          >
            All
            <span className="pill-count">{total}</span>
          </button>
          {categories.map((c) => (
            <button
              key={c}
              className={`pill${category === c ? ' active' : ''}`}
              onClick={() => props.onCategoryChange(category === c ? null : c)}
            >
              {c}
              <span className="pill-count">{labs.filter((l) => l.category === c).length}</span>
            </button>
          ))}
        </div>

        <div className="seg seg-sm">
          {(['all', 'todo', 'done'] as StatusFilter[]).map((s) => (
            <button
              key={s}
              className={`seg-btn${status === s ? ' active' : ''}`}
              onClick={() => props.onStatusChange(s)}
            >
              {s === 'all' ? 'Semua' : s === 'done' ? 'Sudah diambil' : 'Belum'}
            </button>
          ))}
        </div>
      </div>

      <nav className="lab-list">
        {labs.map((lab) => {
          const done = doneIds.has(lab.id)
          const hidden = status === 'done' ? !done : status === 'todo' ? done : false
          if (hidden) return null
          return (
            <button
              key={lab.id}
              className={`lab-row${selectedId === lab.id ? ' active' : ''}${done ? ' done' : ''}`}
              onClick={() => props.onSelect(lab.id)}
            >
              <span className="lab-check">{done ? '✓' : ''}</span>
              <span className="lab-code">{formatCode(lab.code)}</span>
              <span className="lab-name">{lab.name}</span>
            </button>
          )
        })}
        {labs.length === 0 && <div className="no-results">Tidak ada lab yang cocok</div>}
      </nav>
    </div>
  )
}
