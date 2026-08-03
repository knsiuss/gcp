import { catalog } from '../generated/catalog'
import type { ArcadeState } from '../lib/useArcade'
import { ProfileCard } from './ProfileCard'
import { QuotaCard } from './QuotaCard'

interface DashboardProps {
  arcade: ArcadeState
  onBrowse: () => void
  onOpenLab: (id: string) => void
}

function BadgeTile({
  name,
  earnedAt,
  lab,
  onOpen,
}: {
  name: string
  earnedAt: string | null
  lab: { id: string; name: string } | null
  onOpen: (id: string) => void
}) {
  return (
    <div className={`badge-tile${lab ? ' matched' : ''}`}>
      <div className="badge-tile-top">
        <span className="badge-medal">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="9" r="5" />
            <path d="M9 13.5 7.5 21 12 18.5 16.5 21 15 13.5" />
          </svg>
        </span>
        {lab && (
          <button className="badge-link" onClick={() => onOpen(lab.id)} title={`Buka ${lab.name}`}>
            Lab ↗
          </button>
        )}
      </div>
      <div className="badge-tile-name">{name}</div>
      {lab ? (
        <div className="badge-tile-sub">{lab.name}</div>
      ) : (
        <div className="badge-tile-sub muted">{earnedAt ?? ''}</div>
      )}
    </div>
  )
}

export function Dashboard({ arcade, onBrowse, onOpenLab }: DashboardProps) {
  const { stats } = arcade

  const labByBadge = new Map<string, { id: string; name: string }>()
  for (const [labId, m] of stats.matches.entries()) {
    const lab = catalog.find((l) => l.id === labId)
    if (lab) labByBadge.set(m.badgeName, { id: lab.id, name: lab.name })
  }

  const doneCount = stats.doneIds.size
  const allBadges = stats.badges

  const statCards = [
    { label: 'Total labs', value: catalog.length },
    { label: 'Badge diambil', value: doneCount, sub: `${catalog.length - doneCount} tersisa` },
    { label: 'Bulan ini', value: stats.monthBadges, sub: `target ${arcade.targets.monthlyBadges}` },
    { label: 'Arcade Points', value: stats.pointsEstimate, sub: `Legend ${arcade.targets.legendTarget}` },
  ]

  return (
    <div className="dash">
      <section className="hero">
        <p className="hero-kicker">Google Cloud Arcade 2026</p>
        <h1 className="hero-title">Arcade Labs.</h1>
        <p className="hero-sub">
          Koleksi script otomatis untuk lab Google Cloud Skills Boost. Tandai badge yang sudah kamu ambil, pantau
          kuota Arcade 2026, dan salin command siap pakai untuk Cloud Shell.
        </p>
        <div className="hero-actions">
          <a className="btn" href="https://go.cloudskillsboost.google/arcade" target="_blank" rel="noreferrer">
            Buka Google Arcade ↗
          </a>
          <button className="btn ghost" onClick={onBrowse}>
            Lihat Labs
          </button>
        </div>
      </section>

      <section className="stats">
        {statCards.map((s) => (
          <div key={s.label} className="stat">
            <div className="stat-num">{typeof s.value === 'number' ? s.value : '—'}</div>
            <div className="stat-label">{s.label}</div>
            {s.sub && <div className="stat-sub">{s.sub}</div>}
          </div>
        ))}
      </section>

      <div className="cards">
        <ProfileCard arcade={arcade} />
        <QuotaCard arcade={arcade} />
      </div>

      <section className="badges-sec">
        <div className="badges-head">
          <h2>Skill Badges</h2>
          <span className="badges-count">
            {allBadges.length} dari Google Skills
            {allBadges.length > 0 && ' · ' + stats.matches.size + ' cocok dengan lab'}
          </span>
        </div>
        {allBadges.length === 0 ? (
          <p className="empty-note">
            Belum ada data badge. Tempel public profile URL kamu di kartu Connect di atas.
          </p>
        ) : (
          <div className="badge-grid">
            {allBadges.map((b, i) => (
              <BadgeTile key={`${b.name}-${i}`} name={b.name} earnedAt={b.earnedAt} lab={labByBadge.get(b.name) ?? null} onOpen={onOpenLab} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
