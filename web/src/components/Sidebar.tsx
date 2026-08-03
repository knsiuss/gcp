import type { Lab, StatusFilter } from '../lib/types'
import { formatCode } from '../lib/catalog'

interface SidebarProps {
  labs: Lab[]
  total: number
  categories: string[]
  query: string
  category: string | null
  status: StatusFilter
  selectedId: string | null
  view: 'dashboard' | 'labs'
  doneIds: Set<string>
  onQueryChange: (q: string) => void
  onCategoryChange: (c: string | null) => void
  onStatusChange: (s: StatusFilter) => void
  onSelect: (id: string) => void
  onViewChange: (v: 'dashboard' | 'labs') => void
}

export function Sidebar(props: SidebarProps) {
  const { labs, total, categories, query, category, status, selectedId, view, doneIds } = props

  return (
    <aside className="sidebar">
      <div className="brand">
        <div className="brand-mark">▦</div>
        <div className="brand-text">
          <div className="brand-title">Arcade Labs</div>
          <div className="brand-sub">GCP solver scripts</div>
        </div>
      </div>

      <nav className="nav-tabs">
        <button className={`nav-tab${view === 'dashboard' ? ' active' : ''}`} onClick={() => props.onViewChange('dashboard')}>
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="7" height="9" rx="1.5" />
            <rect x="14" y="3" width="7" height="5" rx="1.5" />
            <rect x="14" y="12" width="7" height="9" rx="1.5" />
            <rect x="3" y="16" width="7" height="5" rx="1.5" />
          </svg>
          Dashboard
        </button>
        <button className={`nav-tab${view === 'labs' ? ' active' : ''}`} onClick={() => props.onViewChange('labs')}>
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
          </svg>
          Labs
          <span className="nav-count">{total}</span>
        </button>
      </nav>

      <div className="search">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        <input
          type="text"
          value={query}
          onChange={(e) => props.onQueryChange(e.target.value)}
          placeholder="Search labs…"
          aria-label="Search labs"
        />
      </div>

      <div className="chips">
        <button className={`chip${category === null ? ' active' : ''}`} onClick={() => props.onCategoryChange(null)}>
          All
          <span className="chip-count">{total}</span>
        </button>
        {categories.map((c) => (
          <button
            key={c}
            className={`chip${category === c ? ' active' : ''}`}
            onClick={() => props.onCategoryChange(category === c ? null : c)}
          >
            {c}
            <span className="chip-count">{labs.filter((l) => l.category === c).length}</span>
          </button>
        ))}
      </div>

      <div className="status-filter">
        {(['all', 'todo', 'done'] as StatusFilter[]).map((s) => (
          <button
            key={s}
            className={`status-btn${status === s ? ' active' : ''}`}
            onClick={() => props.onStatusChange(s)}
          >
            {s === 'all' ? 'Semua' : s === 'done' ? 'Sudah diambil' : 'Belum diambil'}
          </button>
        ))}
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
        {labs.length === 0 && <div className="no-results">No labs found</div>}
      </nav>
    </aside>
  )
}
