import { catalog, generatedAt } from './generated/catalog'
import { useArcade } from './lib/useArcade'
import { Topbar } from './components/Topbar'
import { Dashboard } from './components/Dashboard'
import './index.css'

export default function App() {
  const arcade = useArcade()

  return (
    <div className="app">
      <Topbar />

      <main className="main">
        <Dashboard arcade={arcade} />
      </main>

      <footer className="footer">
        {catalog.length} lab scripts · generated {new Date(generatedAt).toLocaleDateString()}
      </footer>
    </div>
  )
}
