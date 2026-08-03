import { useState } from 'react'
import type { LabFile } from '../lib/types'
import { CopyButton } from './CopyButton'

function lineCount(content: string) {
  let n = 1
  for (let i = 0; i < content.length; i++) if (content[i] === '\n') n++
  return n
}

export function CodeBlock({ file }: { file: LabFile }) {
  const [wrap, setWrap] = useState(false)
  const lines = lineCount(file.content)

  const download = () => {
    const blob = new Blob([file.content], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = file.name
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="codeblock">
      <div className="codeblock-head">
        <span className="file-kind">{file.kind === 'script' ? 'script' : 'config'}</span>
        <span className="codeblock-actions">
          <button className="icon-btn" onClick={() => setWrap((w) => !w)} title={wrap ? 'Unwrap lines' : 'Wrap lines'}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M4 6h16M4 12h16M4 18h9" />
              <path d="m16 15 3 3-3 3" />
            </svg>
          </button>
          <button className="icon-btn" onClick={download} title={`Download ${file.name}`}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 3v12m0 0 4-4m-4 4-4-4" />
              <path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2" />
            </svg>
          </button>
          <CopyButton text={file.content} label="Copy" />
        </span>
      </div>
      <div className="codeblock-body">
        <pre className={wrap ? 'wrapped' : ''}>{file.content}</pre>
        <span className="linecount">{lines.toLocaleString()} lines</span>
      </div>
    </div>
  )
}
