import { useMemo, useState } from 'react'
import { catalog, generatedAt } from './generated/catalog'
import { allCategories, filterLabs } from './lib/catalog'
import type { StatusFilter } from './lib/types'
import { useArcade } from './lib/useArcade'
import { Sidebar } from './components/Sidebar'
import { LabDetail } from './components/LabDetail'
import { Dashboard } from './components/Dashboard'
import './index.css'

export default function App() {
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState<string | null>(null)
  const [status, setStatus] = useState<StatusFilter>('all')
  const [view, setView] = useState<'dashboard' | 'labs'>('dashboard')
  const [selectedId, setSelectedId] = useState(catalog[0]?.id ?? null)
  const arcade = useArcade()

  const labs = useMemo(() => filterLabs(catalog, query, category), [query, category])
  const selected = catalog.find((l) => l.id === selectedId) ?? catalog[0] ?? null

  const goView = (v: 'dashboard' | 'labs') => {
    setView(v)
    if (v === 'labs' && !selected) setSelectedId(catalog[0]?.id ?? null)
  }

  const selectLab = (id: string) => {
    setSelectedId(id)
    setView('labs')
  }

  return (
    <div className="app">
      <Sidebar
        labs={labs}
        total={catalog.length}
        categories={allCategories}
        query={query}
        category={category}
        status={status}
        selectedId={selected?.id ?? null}
        view={view}
        doneIds={arcade.stats.doneIds}
        onQueryChange={setQuery}
        onCategoryChange={setCategory}
        onStatusChange={setStatus}
        onSelect={selectLab}
        onViewChange={goView}
      />
      <main className="main">
        {view === 'dashboard' ? (
          <Dashboard arcade={arcade} onBrowse={() => goView('labs')} />
        ) : selected ? (
          <LabDetail key={selected.id} lab={selected} arcade={arcade} />
        ) : (
          <div className="empty">No lab matches your search.</div>
        )}
        <footer className="footer">
          {catalog.length} labs · generated {new Date(generatedAt).toLocaleDateString()} · repo GitHub{' '}
          <a className="footer-link" href="https://github.com/knsiuss/gcp" target="_blank" rel="noreferrer">
            knsiuss/gcp
          </a>
        </footer>
      </main>
    </div>
  )
}
