import { useState } from 'react'
import type { Lab } from '../lib/types'
import { formatCode } from '../lib/catalog'
import type { ArcadeState } from '../lib/useArcade'
import { CopyButton } from './CopyButton'
import { CodeBlock } from './CodeBlock'

interface LabDetailProps {
  lab: Lab
  arcade: ArcadeState
}

function ReadmeView({ content }: { content: string }) {
  const lines = content.split('\n')
  const blocks: React.ReactNode[] = []
  let inFence = false
  let fenceLines: string[] = []
  let para: string[] = []

  const flushPara = (key: string) => {
    if (para.length) {
      blocks.push(
        <p key={key} className="rm-p">
          {para.join(' ')}
        </p>,
      )
      para = []
    }
  }

  lines.forEach((raw, i) => {
    const line = raw.trimEnd()
    if (line.startsWith('```')) {
      if (inFence) {
        blocks.push(
          <pre key={`f${i}`} className="rm-fence">
            {fenceLines.join('\n')}
          </pre>,
        )
        fenceLines = []
      }
      inFence = !inFence
      return
    }
    if (inFence) {
      fenceLines.push(line)
      return
    }
    const heading = line.match(/^(#{1,4})\s+(.*)$/)
    if (heading) {
      flushPara(`p${i}`)
      const level = heading[1].length
      const tag = level <= 2 ? 'h2' : 'h3'
      const text = heading[2].replace(/\*\*/g, '')
      blocks.push(createEl(tag, { key: `h${i}` }, text))
      return
    }
    if (/^\s*[-*]\s+/.test(line)) {
      flushPara(`p${i}`)
      blocks.push(
        <li key={`l${i}`} className="rm-li">
          {line.replace(/^\s*[-*]\s+/, '').replace(/\*\*/g, '')}
        </li>,
      )
      return
    }
    if (line.trim() === '') {
      flushPara(`p${i}`)
      return
    }
    para.push(line.replace(/\*\*/g, ''))
  })
  flushPara('pend')

  return <div className="readme">{blocks}</div>
}

function createEl(tag: 'h2' | 'h3', props: Record<string, unknown>, text: string) {
  if (tag === 'h2') return <h2 {...props}>{text}</h2>
  return <h3 {...props}>{text}</h3>
}

export function LabDetail({ lab, arcade }: LabDetailProps) {
  const [activeFile, setActiveFile] = useState(lab.primaryFile)

  const active = lab.files.find((f) => f.name === activeFile) ?? lab.files[0]
  const runScript = lab.files.find((f) => f.name === lab.primaryFile) ?? lab.files[0]

  const done = arcade.stats.doneIds.has(lab.id)
  const matched = arcade.stats.matches.get(lab.id)
  const manual = arcade.overrides[lab.id] !== undefined

  const runText = lab.runCommands.join('\n')
  const fileRunText = `git clone https://github.com/knsiuss/gcp.git gcp-labs\ncd gcp-labs/${lab.folder}\nchmod +x ${runScript.name}\n./${runScript.name}`

  return (
    <article className="detail">
      <header className="detail-head">
        <div className="detail-meta">
          <span className="code-badge">{formatCode(lab.code)}</span>
          <span className="cat-badge">{lab.category}</span>
          {done && <span className="done-badge">Badge diambil</span>}
        </div>
        <h1 className="detail-title">{lab.name}</h1>
        {lab.description && <p className="detail-desc">{lab.description}</p>}
        <div className="detail-actions">
          <button className={`btn${done ? ' done' : ''}`} onClick={() => arcade.toggleDone(lab.id, !done)}>
            {done ? 'Tandai belum diambil' : 'Tandai sudah diambil'}
          </button>
          {manual && <span className="manual-note">set manual</span>}
        </div>
        {matched && (
          <div className="match-note">
            Badge: <strong>“{matched.badgeName}”</strong>
            {matched.earnedAt ? ` · ${matched.earnedAt}` : ''}
          </div>
        )}
      </header>

      {lab.variables.length > 0 && (
        <section className="card">
          <h2 className="card-title">Inputs prompted by script</h2>
          <div className="vars">
            {lab.variables.map((v, i) => (
              <div key={i} className="var">
                <span className="var-prompt">{v.prompt}</span>
                <span className="var-file">{v.files.join(', ')}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      <section className="card">
        <h2 className="card-title">Run in Cloud Shell</h2>
        <div className="run">
          <pre className="run-pre">
            {lab.runCommands.map((c) => (
              <div key={c}>{c}</div>
            ))}
          </pre>
          <CopyButton text={runText} label="Copy all" />
        </div>
      </section>

      {lab.readme && (
        <section className="card">
          <h2 className="card-title">Notes</h2>
          <ReadmeView content={lab.readme} />
        </section>
      )}

      <section className="card">
        <h2 className="card-title">Files</h2>
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
        {runScript && runScript.name !== active?.name && (
          <div className="run" style={{ marginTop: 12 }}>
            <pre className="run-pre">
              <div>git clone https://github.com/knsiuss/gcp.git gcp-labs</div>
              <div>cd gcp-labs/{lab.folder}</div>
              <div>chmod +x {runScript.name}</div>
              <div>./{runScript.name}</div>
            </pre>
            <CopyButton text={fileRunText} label="Copy" />
          </div>
        )}
      </section>
    </article>
  )
}
