interface TopbarProps {
  view: 'dashboard' | 'labs'
  onViewChange: (v: 'dashboard' | 'labs') => void
}

export function Topbar({ view, onViewChange }: TopbarProps) {
  return (
    <header className="topbar">
      <div className="brand">
        <span className="brand-dot" />
        <span className="brand-name">Arcade Labs</span>
      </div>

      <div className="seg" role="tablist" aria-label="Navigation">
        <button
          role="tab"
          aria-selected={view === 'dashboard'}
          className={`seg-btn${view === 'dashboard' ? ' active' : ''}`}
          onClick={() => onViewChange('dashboard')}
        >
          Dashboard
        </button>
        <button
          role="tab"
          aria-selected={view === 'labs'}
          className={`seg-btn${view === 'labs' ? ' active' : ''}`}
          onClick={() => onViewChange('labs')}
        >
          Labs
        </button>
      </div>

      <div className="topbar-links">
        <a href="https://go.cloudskillsboost.google/arcade" target="_blank" rel="noreferrer">
          Arcade 2026 ↗
        </a>
        <a href="https://github.com/knsiuss/gcp" target="_blank" rel="noreferrer">
          GitHub ↗
        </a>
      </div>
    </header>
  )
}
