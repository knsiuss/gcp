import { useEffect, useMemo, useState } from 'react'
import { catalog } from '../generated/catalog'
import type { ArcadeState } from '../lib/useArcade'
import type { StatusFilter } from '../lib/types'
import { fetchSkillsBadges, isBadgeEarned, normalizeBadgeTitle, type SkillsBadge } from '../lib/skillsBadges'
import { ProfileCard } from './ProfileCard'
import { QuotaCard } from './QuotaCard'

interface DashboardProps {
  arcade: ArcadeState
  onBrowse: () => void
  onOpenLab: (id: string) => void
}

const LEVEL_LABEL: Record<string, string> = {
  introductory: 'Pemula',
  intermediate: 'Menengah',
  advanced: 'Lanjutan',
}

function BadgeTile({ badge, earned, onOpen }: { badge: SkillsBadge; earned: boolean; onOpen: (id: string) => void }) {
  const lab = catalog.find((l) => l.name === badge.title)

  return (
    <div className={`badge-tile${earned ? ' earned' : ''}`}>
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
      <div className="badge-tile-name">{badge.title}</div>
      <div className="badge-tile-sub">
        {earned ? (
          <span className="earned-tag">✓ Selesai</span>
        ) : (
          <span className="todo-tag">Belum</span>
        )}
        {badge.level && <span className="level-tag">{LEVEL_LABEL[badge.level] ?? badge.level}</span>}
        {badge.duration && <span className="level-tag">{badge.duration}</span>}
      </div>
    </div>
  )
}

export function Dashboard({ arcade, onBrowse, onOpenLab }: DashboardProps) {
  const { stats, targets } = arcade
  const [catalogBadges, setCatalogBadges] = useState<SkillsBadge[]>([])
  const [fetchedAt, setFetchedAt] = useState<string | null>(null)
  const [filter, setFilter] = useState<StatusFilter>('all')

  useEffect(() => {
    fetchSkillsBadges().then((data) => {
      if (data) {
        setCatalogBadges(data.badges)
        setFetchedAt(data.fetchedAt)
      }
    })
  }, [])

  const earnedNames = useMemo(() => new Set(stats.badges.map((b) => normalizeBadgeTitle(b.name))), [stats.badges])

  const earnedCount = useMemo(
    () => catalogBadges.filter((b) => isBadgeEarned(b, earnedNames)).length,
    [catalogBadges, earnedNames],
  )

  const visibleBadges = useMemo(() => {
    if (filter === 'all') return catalogBadges
    const wantDone = filter === 'done'
    return catalogBadges.filter((b) => isBadgeEarned(b, earnedNames) === wantDone)
  }, [catalogBadges, filter, earnedNames])

  const statCards = [
    { label: 'Total labs', value: catalog.length },
    { label: 'Badge selesai', value: earnedCount, sub: `${Math.max(0, catalogBadges.length - earnedCount)} dari ${catalogBadges.length} tersisa` },
    { label: 'Bulan ini', value: stats.monthBadges, sub: `target ${targets.monthlyBadges}` },
    { label: 'Arcade Points', value: stats.pointsEstimate, sub: `Legend ${targets.legendTarget}` },
  ]

  return (
    <div className="dash">
      <section className="hero">
        <p className="hero-kicker">Google Cloud Arcade 2026</p>
        <h1 className="hero-title">Arcade Labs.</h1>
        <p className="hero-sub">
          Koleksi script otomatis untuk lab Google Cloud Skills Boost. Pantau progress skill badge dari Google Skills
          (skills.google/catalog), tandai yang sudah kamu ambil, dan salin command siap pakai untuk Cloud Shell.
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
          <div>
            <h2>Skill Badges</h2>
            <span className="badges-count">
              {catalogBadges.length} dari Google Skills
              {catalogBadges.length > 0 && ` · ${earnedCount} selesai`}
              {fetchedAt && ` · ${new Date(fetchedAt).toLocaleDateString()}`}
            </span>
          </div>
          <div className="seg seg-sm">
            {(['all', 'todo', 'done'] as StatusFilter[]).map((s) => (
              <button
                key={s}
                className={`seg-btn${filter === s ? ' active' : ''}`}
                onClick={() => setFilter(s)}
              >
                {s === 'all' ? 'Semua' : s === 'done' ? 'Selesai' : 'Belum'}
              </button>
            ))}
          </div>
        </div>

        {catalogBadges.length === 0 ? (
          <p className="empty-note">
            Gagal memuat katalog badge dari skills.google. Coba muat ulang halaman.
          </p>
        ) : visibleBadges.length === 0 ? (
          <p className="empty-note">
            Tidak ada badge {filter === 'done' ? 'yang sudah selesai' : 'yang belum diambil'}.
          </p>
        ) : (
          <div className="badge-grid">
            {visibleBadges.map((b) => (
              <BadgeTile key={b.title} badge={b} earned={isBadgeEarned(b, earnedNames)} onOpen={onOpenLab} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
