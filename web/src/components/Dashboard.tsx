import { useEffect, useMemo, useState } from 'react'
import { catalog } from '../generated/catalog'
import type { ArcadeState } from '../lib/useArcade'
import type { StatusFilter } from '../lib/types'
import { fetchSkillsBadges, isBadgeEarned, normalizeBadgeTitle, type SkillsBadge } from '../lib/skillsBadges'
import { fetchSilabus, courseTemplateId, type SilabusBadge, type SilabusFile } from '../lib/silabus'
import { ProfileCard } from './ProfileCard'
import { QuotaCard } from './QuotaCard'
import { BadgeDetail } from './BadgeDetail'

interface DashboardProps {
  arcade: ArcadeState
}

const LEVEL_LABEL: Record<string, string> = {
  introductory: 'Pemula',
  intermediate: 'Menengah',
  advanced: 'Lanjutan',
}

function BadgeTile({ badge, earned }: { badge: SkillsBadge; earned: boolean }) {
  return (
    <div className={`badge-tile${earned ? ' earned' : ''}`}>
      <div className="badge-tile-top">
        <span className="badge-medal">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="9" r="5" />
            <path d="M9 13.5 7.5 21 12 18.5 16.5 21 15 13.5" />
          </svg>
        </span>
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

function SilabusBadgeTile({
  badge,
  earned,
  onClick,
}: {
  badge: SilabusBadge
  earned: boolean
  onClick: () => void
}) {
  return (
    <button className={`sil-badge-tile${earned ? ' earned' : ''}`} onClick={onClick}>
      <div className="badge-tile-top">
        <span className="badge-medal">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="9" r="5" />
            <path d="M9 13.5 7.5 21 12 18.5 16.5 21 15 13.5" />
          </svg>
        </span>
        <span className="sil-badge-meta">
          {badge.labs != null && `${badge.labs} labs`}
          {badge.credits != null && ` · ${badge.credits} cr`}
        </span>
      </div>
      <div className="badge-tile-name">{badge.title}</div>
      <div className="badge-tile-sub">
        {earned ? <span className="earned-tag">✓ Selesai</span> : <span className="todo-tag">Belum</span>}
        <span className="level-tag">Lihat cara ↗</span>
      </div>
    </button>
  )
}

function GameCard({ game }: { game: SilabusFile['games'][number] }) {
  const statusLabel =
    game.status === 'active'
      ? { text: 'Aktif', cls: 'active' }
      : game.status === 'closed'
        ? { text: 'Ditutup', cls: 'closed' }
        : { text: 'Coming Soon', cls: 'soon' }

  return (
    <div className={`game-card${game.status === 'active' ? '' : ' muted'}`}>
      <div className="game-card-top">
        <span className="game-status" data-status={statusLabel.cls}>
          {statusLabel.text}
        </span>
        {game.url ? (
          <a className="badge-link" href={game.url} target="_blank" rel="noreferrer">
            Buka ↗
          </a>
        ) : (
          <span className="badge-link dim">Segera</span>
        )}
      </div>
      <div className="game-name">{game.name}</div>
      <div className="game-code">
        {game.accessCode ? (
          <>
            <code>{game.accessCode}</code>
            <span className="game-code-label">access code</span>
          </>
        ) : (
          <span className="game-code-label empty">belum ada kode</span>
        )}
      </div>
    </div>
  )
}

export function Dashboard({ arcade }: DashboardProps) {
  const { stats, targets } = arcade
  const [catalogBadges, setCatalogBadges] = useState<SkillsBadge[]>([])
  const [fetchedAt, setFetchedAt] = useState<string | null>(null)
  const [filter, setFilter] = useState<StatusFilter>('all')
  const [silabus, setSilabus] = useState<SilabusFile | null>(null)
  const [detail, setDetail] = useState<{ badge: SilabusBadge; levelLabel: string; labId: string | null } | null>(null)

  useEffect(() => {
    fetchSkillsBadges().then((data) => {
      if (data) {
        setCatalogBadges(data.badges)
        setFetchedAt(data.fetchedAt)
      }
    })
    fetchSilabus().then(setSilabus)
  }, [])

  const earnedNames = useMemo(() => new Set(stats.badges.map((b) => normalizeBadgeTitle(b.name))), [stats.badges])

  const catalogByTemplate = useMemo(() => {
    const map = new Map<string, SkillsBadge>()
    for (const b of catalogBadges) {
      const id = courseTemplateId(b.path)
      if (id) map.set(id, b)
    }
    return map
  }, [catalogBadges])

  const earnedCount = useMemo(
    () => catalogBadges.filter((b) => isBadgeEarned(b, earnedNames)).length,
    [catalogBadges, earnedNames],
  )

  const silabusBadges = useMemo(() => silabus?.levels.flatMap((l) => l.badges) ?? [], [silabus])
  const silabusEarnedCount = useMemo(
    () => silabusBadges.filter((b) => isBadgeEarned(b, earnedNames)).length,
    [silabusBadges, earnedNames],
  )

  const findLabForBadge = (badge: SilabusBadge) => {
    const templateId = courseTemplateId(badge.url)
    const catBadge = templateId ? catalogByTemplate.get(templateId) : undefined
    return catBadge ? (catalog.find((l) => l.name === catBadge.title) ?? null) : null
  }

  const visibleBadges = useMemo(() => {
    if (filter === 'all') return catalogBadges
    const wantDone = filter === 'done'
    return catalogBadges.filter((b) => isBadgeEarned(b, earnedNames) === wantDone)
  }, [catalogBadges, filter, earnedNames])

  const statCards = [
    { label: 'Total lab (katalog)', value: catalog.length },
    { label: 'Badge Google Skills', value: earnedCount, sub: `${Math.max(0, catalogBadges.length - earnedCount)} dari ${catalogBadges.length} tersisa` },
    { label: 'Silabus selesai', value: silabusEarnedCount, sub: `dari ${silabusBadges.length} badge silabus` },
    { label: 'Arcade Points', value: stats.pointsEstimate, sub: `Legend ${targets.legendTarget}` },
  ]

  const openDetail = (badge: SilabusBadge) => {
    const level = silabus?.levels.find((l) => l.badges.includes(badge))
    const lab = findLabForBadge(badge)
    setDetail({ badge, levelLabel: level?.level ?? 'other', labId: lab?.id ?? null })
  }

  const detailLab = detail ? (catalog.find((l) => l.id === detail.labId) ?? null) : null
  const detailEarned = detail ? isBadgeEarned(detail.badge, earnedNames) : false

  return (
    <div className="dash">
      <section className="hero">
        <p className="hero-kicker">Google Cloud Arcade 2026 · Fasilitator</p>
        <h1 className="hero-title">Arcade Labs.</h1>
        <p className="hero-sub">
          Silabus program Fasilitator Arcade 2026: 6 Arcade Games per bulan plus 51 badge keahlian pilihan. Klik badge
          untuk melihat perintah Cloud Shell siap pakai, atau panduan langkah demi langkah untuk yang tidak bisa
          diotomatisasi.
        </p>
        <div className="hero-actions">
          <a className="btn" href="https://rsvp.withgoogle.com/events/arcade-fasilitator-id/silabus" target="_blank" rel="noreferrer">
            Silabus resmi ↗
          </a>
          <a className="btn ghost" href="https://go.cloudskillsboost.google/arcade" target="_blank" rel="noreferrer">
            Google Arcade ↗
          </a>
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

      {silabus && (
        <>
          <section className="badges-sec">
            <div className="badges-head">
              <div>
                <h2>Arcade Games</h2>
                <span className="badges-count">
                  {silabus.games.length} game bulan ini · {silabus.games.filter((g) => g.status === 'active').length} aktif ·{' '}
                  {new Date(silabus.fetchedAt).toLocaleDateString()}
                </span>
              </div>
            </div>
            <div className="game-grid">
              {silabus.games.map((g) => (
                <GameCard key={g.name} game={g} />
              ))}
            </div>
          </section>

          <section className="badges-sec">
            <div className="badges-head">
              <div>
                <h2>Silabus Badge Keahlian</h2>
                <span className="badges-count">
                  {silabus.totalBadges} badge pilihan · {silabusEarnedCount} selesai
                </span>
              </div>
            </div>

            {silabus.levels.map((level) => (
              <div key={level.level} className="sil-level">
                <div className="sil-level-head">
                  <h3>{level.title}</h3>
                  <span className="badges-count">{level.badges.length} badge</span>
                </div>
                <div className="badge-grid">
                  {level.badges.map((b) => (
                    <SilabusBadgeTile
                      key={b.url ?? b.title}
                      badge={b}
                      earned={isBadgeEarned(b, earnedNames)}
                      onClick={() => openDetail(b)}
                    />
                  ))}
                </div>
              </div>
            ))}
          </section>
        </>
      )}

      <section className="badges-sec">
        <div className="badges-head">
          <div>
            <h2>Semua Badge Google Skills</h2>
            <span className="badges-count">
              {catalogBadges.length} dari katalog Google Skills
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
              <BadgeTile key={b.title} badge={b} earned={isBadgeEarned(b, earnedNames)} />
            ))}
          </div>
        )}
      </section>

      {detail && (
        <BadgeDetail
          badge={detail.badge}
          levelLabel={detail.levelLabel}
          lab={detailLab}
          earned={detailEarned}
          arcade={arcade}
          onClose={() => setDetail(null)}
        />
      )}
    </div>
  )
}
