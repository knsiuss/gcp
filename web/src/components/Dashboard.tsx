import { catalog } from '../generated/catalog'
import type { ArcadeState } from '../lib/useArcade'
import { ProfileCard } from './ProfileCard'
import { QuotaCard } from './QuotaCard'

interface DashboardProps {
  arcade: ArcadeState
  onBrowse: () => void
}

export function Dashboard({ arcade, onBrowse }: DashboardProps) {
  const { stats } = arcade
  const { doneIds, monthBadges, totalBadges, pointsEstimate, matches } = stats

  const doneCount = doneIds.size
  const unmatchedBadges = stats.badges.filter((b) => ![...matches.values()].some((m) => m.badgeName === b.name))

  const statCards = [
    { label: 'Total labs', value: catalog.length },
    { label: 'Badge diambil', value: doneCount, sub: `${catalog.length - doneCount} belum` },
    { label: 'Selesai bulan ini', value: monthBadges },
    { label: 'Estimasi poin', value: pointsEstimate, sub: 'Arcade 2026' },
  ]

  return (
    <article className="dashboard">
      <section className="hero">
        <div className="hero-overline">Google Cloud Arcade 2026</div>
        <h1 className="hero-title">Arcade Labs Solver Portal</h1>
        <p className="hero-sub">
          Koleksi script otomatis untuk semua lab Google Cloud Skills Boost — lengkap dengan tracker badge, quota
          Arcade 2026, dan command siap salin untuk Cloud Shell.
        </p>
        <div className="hero-actions">
          <a className="btn-primary" href="https://go.cloudskillsboost.google/arcade" target="_blank" rel="noreferrer">
            Buka Google Arcade →
          </a>
          <button className="btn-ghost" onClick={onBrowse}>
            Lihat daftar lab
          </button>
        </div>
      </section>

      <section className="stat-row">
        {statCards.map((s) => (
          <div key={s.label} className="stat-card">
            <div className="stat-value">{typeof s.value === 'number' ? s.value : '—'}</div>
            <div className="stat-label">{s.label}</div>
            {s.sub && <div className="stat-sub">{s.sub}</div>}
          </div>
        ))}
      </section>

      <div className="dash-grid">
        <ProfileCard arcade={arcade} />
        <QuotaCard arcade={arcade} />
      </div>

      <section className="card">
        <h2 className="card-title">Badge ↔ Lab mapping</h2>
        {totalBadges === 0 ? (
          <p className="dim">Belum ada data badge. Connect profil untuk melihat pemetaan badge ke lab solver.</p>
        ) : (
          <div className="badge-grid">
            <div className="badge-col">
              <h3>Matched · {matches.size} badge → lab</h3>
              <ul className="badge-list">
                {[...matches.entries()].map(([labId, m]) => {
                  const lab = catalog.find((l) => l.id === labId)
                  return (
                    <li key={labId} className="badge-li">
                      <span className="badge-name">{m.badgeName}</span>
                      <span className="badge-to">→</span>
                      <span className="badge-lab">{lab?.name ?? labId}</span>
                    </li>
                  )
                })}
              </ul>
            </div>
            <div className="badge-col">
              <h3>Belum matched · {unmatchedBadges.length} badge</h3>
              <ul className="badge-list">
                {unmatchedBadges.map((b, i) => (
                  <li key={i} className="badge-li">
                    <span className="badge-name">{b.name}</span>
                    <span className="badge-date">{b.earnedAt ?? ''}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </section>
    </article>
  )
}
