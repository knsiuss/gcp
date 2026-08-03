import type { ArcadeState } from '../lib/useArcade'

interface QuotaCardProps {
  arcade: ArcadeState
}

function Bar({ value, max, label }: { value: number; max: number; label: string }) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0
  return (
    <div className="quota-bar">
      <div className="quota-bar-label">
        <span>{label}</span>
        <strong>
          {value} / {max}
        </strong>
      </div>
      <div className="bar">
        <div className="bar-fill" style={{ width: `${pct}%` }} />
      </div>
      <div className="quota-bar-note">{pct >= 100 ? 'Target tercapai ✓' : `${100 - pct}% menuju target`}</div>
    </div>
  )
}

export function QuotaCard({ arcade }: QuotaCardProps) {
  const { stats, targets, updateTargets } = arcade

  return (
    <section className="card quota-card">
      <h2 className="card-title">Arcade 2026 · Quota Tracker</h2>
      <p className="card-hint">
        Season Google Cloud Arcade 2026 berjalan 1 Jan – 31 Des 2026. 1 game = 1 Arcade Point; 2 skill badge = 1 poin
        (default konversi bisa kamu ubah).
      </p>

      <div className="quota-inputs">
        <label>
          <span>Target badge/bulan</span>
          <input
            type="number"
            min={1}
            value={targets.monthlyBadges}
            onChange={(e) => updateTargets({ monthlyBadges: Math.max(1, Number(e.target.value) || 1) })}
          />
        </label>
        <label>
          <span>Poin per badge</span>
          <input
            type="number"
            min={0.5}
            step={0.5}
            value={targets.pointsPerBadge}
            onChange={(e) => updateTargets({ pointsPerBadge: Math.max(0.5, Number(e.target.value) || 0.5) })}
          />
        </label>
        <label>
          <span>Target Legend (pts)</span>
          <input
            type="number"
            min={1}
            value={targets.legendTarget}
            onChange={(e) => updateTargets({ legendTarget: Math.max(1, Number(e.target.value) || 1) })}
          />
        </label>
      </div>

      <div className="quota-bars">
        <Bar value={stats.monthBadges} max={targets.monthlyBadges} label="Badges bulan ini" />
        <Bar value={stats.pointsEstimate} max={targets.legendTarget} label="Estimasi Arcade Points (season)" />
      </div>

      <div className="quota-footer">
        <span>Total badges profil: <strong>{stats.totalBadges}</strong></span>
        <span>Target harian kasar: <strong>{targets.monthlyBadges > 0 ? (targets.monthlyBadges / 30).toFixed(1) : '—'}/hari</strong></span>
      </div>
    </section>
  )
}
