export function Topbar() {
  return (
    <header className="topbar">
      <div className="brand">
        <span className="brand-dot" />
        <span className="brand-name">Arcade Labs</span>
      </div>

      <div className="topbar-links">
        <a href="https://rsvp.withgoogle.com/events/arcade-fasilitator-id/silabus" target="_blank" rel="noreferrer">
          Silabus ↗
        </a>
        <a href="https://go.cloudskillsboost.google/arcade" target="_blank" rel="noreferrer">
          Arcade 2026 ↗
        </a>
        <a href="https://github.com/knsiuss/gcp" target="_blank" rel="noreferrer">
          GitHub ↗
        </a>
      </div>
    </header>
  )
}
