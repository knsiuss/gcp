import { useState } from 'react'
import type { Lab } from '../lib/types'
import type { ArcadeState } from '../lib/useArcade'
import type { SilabusBadge } from '../lib/silabus'
import { CopyButton } from './CopyButton'
import { CodeBlock } from './CodeBlock'

interface BadgeDetailProps {
  badge: SilabusBadge
  levelLabel: string
  lab: Lab | null
  earned: boolean
  arcade: ArcadeState
  onClose: () => void
}

const LEVEL_TAG: Record<string, string> = {
  beginner: 'Pemula',
  intermediate: 'Menengah',
  advanced: 'Lanjutan',
}

const TUTORIAL_STEPS = [
  'Buka halaman badge di Google Skills menggunakan tombol di atas, lalu klik "Mulai" untuk membuka lab pertama.',
  'Klik "Launch" pada lab. Pilih region terdekat dan tunggu Cloud Console/Cloud Shell terbuka.',
  'Ikuti instruksi lab langkah demi langkah. Beberapa lab butuh tindakan manual di Console (tidak bisa full-otomatis lewat script).',
  'Saat selesai, klik "Check my progress". Pastikan semua task centang hijau, lalu klik "End Lab".',
  'Ulangi untuk semua lab di badge tersebut. Badge otomatis diberikan setelah semua lab selesai.',
  'Tunggu 1–5 menit lalu refresh profil Google Skills untuk melihat badge masuk.',
]

export function BadgeDetail({ badge, levelLabel, lab, earned, arcade, onClose }: BadgeDetailProps) {
  const [activeFile, setActiveFile] = useState<string | null>(lab?.primaryFile ?? null)

  if (!lab) {
    return (
      <div className="modal-backdrop" onClick={onClose}>
        <div className="modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
          <header className="modal-head">
            <div className="modal-meta">
              <span className="level-tag">{LEVEL_TAG[levelLabel] ?? levelLabel}</span>
              {badge.labs != null && <span className="cat-badge">{badge.labs} labs</span>}
              {badge.credits != null && <span className="cat-badge">{badge.credits} credits</span>}
            </div>
            <button className="icon-btn modal-close" onClick={onClose} aria-label="Tutup">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          </header>

          <h2 className="modal-title">{badge.title}</h2>
          <p className="modal-sub">
            Badge ini belum punya script otomatis — kerjakan manual lewat panduan berikut.
          </p>

          <ol className="tutorial">
            {TUTORIAL_STEPS.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ol>

          <div className="modal-actions">
            <button className={`btn${earned ? ' done' : ''}`} onClick={() => arcade.toggleDone(badge.title, !earned)}>
              {earned ? 'Tandai belum diambil' : 'Tandai sudah diambil'}
            </button>
            {badge.url && (
              <a className="btn ghost" href={badge.url} target="_blank" rel="noreferrer">
                Buka di Google Skills ↗
              </a>
            )}
          </div>
        </div>
      </div>
    )
  }

  const runScript = lab.files.find((f) => f.name === lab.primaryFile) ?? lab.files[0]
  const active = lab.files.find((f) => f.name === activeFile) ?? lab.files[0]
  const runText = lab.runCommands.join('\n')
  const fileRunText = `git clone https://github.com/knsiuss/gcp.git gcp-labs\ncd gcp-labs/${lab.folder}\nchmod +x ${runScript.name}\n./${runScript.name}`

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
        <header className="modal-head">
          <div className="modal-meta">
            <span className="level-tag">{LEVEL_TAG[levelLabel] ?? levelLabel}</span>
            {lab.code && <span className="code-badge">{lab.code}</span>}
            {badge.labs != null && <span className="cat-badge">{badge.labs} labs</span>}
            {earned && <span className="done-badge">Badge diambil</span>}
          </div>
          <button className="icon-btn modal-close" onClick={onClose} aria-label="Tutup">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </header>

        <h2 className="modal-title">{badge.title}</h2>
        <p className="modal-sub">
          Ada script otomatis untuk badge ini. Jalankan perintah berikut di Cloud Shell.
        </p>

        <section className="card">
          <h3 className="card-title">Run in Cloud Shell</h3>
          <div className="run">
            <pre className="run-pre">
              {lab.runCommands.map((c) => (
                <div key={c}>{c}</div>
              ))}
            </pre>
            <CopyButton text={runText} label="Copy all" />
          </div>
          <div className="run" style={{ marginTop: 12 }}>
            <pre className="run-pre">
              <div>git clone https://github.com/knsiuss/gcp.git gcp-labs</div>
              <div>cd gcp-labs/{lab.folder}</div>
              <div>chmod +x {runScript.name}</div>
              <div>./{runScript.name}</div>
            </pre>
            <CopyButton text={fileRunText} label="Copy" />
          </div>
        </section>

        {lab.readme && (
          <section className="card">
            <h3 className="card-title">Notes</h3>
            <pre className="run-pre readme-pre">{lab.readme}</pre>
          </section>
        )}

        <section className="card">
          <h3 className="card-title">Files</h3>
          <div className="file-tabs">
            {lab.files.map((f) => (
              <button
                key={f.name}
                className={`file-tab${active?.name === f.name ? ' active' : ''}`}
                onClick={() => setActiveFile(f.name)}
              >
                <span className={`file-tab-kind ${f.kind}`}>{f.kind === 'script' ? '>' : '#'}</span>
                {f.name}
              </button>
            ))}
          </div>
          {active && <CodeBlock file={active} />}
        </section>

        <div className="modal-actions">
          <button className={`btn${earned ? ' done' : ''}`} onClick={() => arcade.toggleDone(lab.id, !earned)}>
            {earned ? 'Tandai belum diambil' : 'Tandai sudah diambil'}
          </button>
          {badge.url && (
            <a className="btn ghost" href={badge.url} target="_blank" rel="noreferrer">
              Buka di Google Skills ↗
            </a>
          )}
        </div>
      </div>
    </div>
  )
}
