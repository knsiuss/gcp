import { useMemo, useState } from 'react'
import { catalog, generatedAt } from './generated/catalog'
import { allCategories, filterLabs } from './lib/catalog'
import type { StatusFilter } from './lib/types'
import { useArcade } from './lib/useArcade'
import { Topbar } from './components/Topbar'
import { LabList } from './components/LabList'
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
    if (v === 'labs' && !selectedId) setSelectedId(catalog[0]?.id ?? null)
  }

  const selectLab = (id: string) => {
    setSelectedId(id)
    setView('labs')
  }

  return (
    <div className="app">
      <Topbar view={view} onViewChange={goView} />

      {view === 'dashboard' ? (
        <main className="main">
          <Dashboard arcade={arcade} onBrowse={() => goView('labs')} onOpenLab={selectLab} />
        </main>
      ) : (
        <main className="main labs-main">
          <LabList
            labs={labs}
            total={catalog.length}
            categories={allCategories}
            query={query}
            category={category}
            status={status}
            selectedId={selected?.id ?? null}
            doneIds={arcade.stats.doneIds}
            onQueryChange={setQuery}
            onCategoryChange={setCategory}
            onStatusChange={setStatus}
            onSelect={selectLab}
          />
          <div className="detail-pane">
            {selected ? (
              <LabDetail key={selected.id} lab={selected} arcade={arcade} />
            ) : (
              <div className="empty">Tidak ada lab yang cocok</div>
            )}
          </div>
        </main>
      )}

      <footer className="footer">
        {catalog.length} labs · generated {new Date(generatedAt).toLocaleDateString()}
      </footer>
    </div>
  )
}
