import type { ArcadeState } from '../lib/useArcade'

interface QuotaCardProps {
  arcade: ArcadeState
}

function Bar({ value, max, label }: { value: number; max: number; label: string }) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0
  return (
    <div className="bar-block">
      <div className="bar-head">
        <span>{label}</span>
        <span className="bar-num">
          {value} / {max}
        </span>
      </div>
      <div className="bar">
        <div className="bar-fill" style={{ width: `${pct}%` }} />
      </div>
      <div className="bar-note">{pct >= 100 ? 'Target tercapai' : `${100 - pct}% menuju target`}</div>
    </div>
  )
}

export function QuotaCard({ arcade }: QuotaCardProps) {
  const { stats, targets, updateTargets } = arcade

  return (
    <section className="card">
      <h2 className="card-title">Quota Arcade 2026</h2>
      <p className="card-hint">
        Season berjalan 1 Jan – 31 Des 2026. Atur target kamu; hitungan mengikuti badge Google Skills.
      </p>

      <div className="fields">
        <label className="field-label">
          <span>Target badge / bulan</span>
          <input
            type="number"
            min={1}
            value={targets.monthlyBadges}
            onChange={(e) => updateTargets({ monthlyBadges: Math.max(1, Number(e.target.value) || 1) })}
          />
        </label>
        <label className="field-label">
          <span>Poin / badge</span>
          <input
            type="number"
            min={0.5}
            step={0.5}
            value={targets.pointsPerBadge}
            onChange={(e) => updateTargets({ pointsPerBadge: Math.max(0.5, Number(e.target.value) || 0.5) })}
          />
        </label>
        <label className="field-label">
          <span>Legend (pts)</span>
          <input
            type="number"
            min={1}
            value={targets.legendTarget}
            onChange={(e) => updateTargets({ legendTarget: Math.max(1, Number(e.target.value) || 1) })}
          />
        </label>
      </div>

      <div className="bars">
        <Bar value={stats.monthBadges} max={targets.monthlyBadges} label="Badges bulan ini" />
        <Bar value={stats.pointsEstimate} max={targets.legendTarget} label="Arcade Points (season)" />
      </div>
    </section>
  )
}
