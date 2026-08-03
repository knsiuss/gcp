import type { ArcadeState } from '../lib/useArcade'

interface ProfileCardProps {
  arcade: ArcadeState
}

export function ProfileCard({ arcade }: ProfileCardProps) {
  const { profileUrl, setProfileUrl, connecting, connectError, connectProfile, clearLocalProfile, effectiveProfile, serverProfile, localProfile } = arcade

  return (
    <section className="card profile-card">
      <h2 className="card-title">Connect Google Skills Profile</h2>
      <p className="card-hint">
        Tempel public profile URL kamu di bawah — badge langsung diambil dari input (via reader proxy, tersimpan di
        browser). Untuk auto-refresh terus-menerus tanpa buka situs, isi{' '}
        <code className="dim-code">web/public/profile-source.json</code> lalu push, dan GitHub Actions akan update tiap
        12 jam.
      </p>

      <div className="profile-form">
        <input
          type="text"
          className="text-input"
          value={profileUrl}
          onChange={(e) => setProfileUrl(e.target.value)}
          placeholder="https://www.cloudskillsboost.google/public_profiles/…"
          spellCheck={false}
        />
        <button className="btn-primary" onClick={() => connectProfile(profileUrl)} disabled={connecting}>
          {connecting ? 'Menghubungkan…' : 'Connect'}
        </button>
      </div>

      {connectError && <div className="form-error">{connectError}</div>}

      {effectiveProfile ? (
        <div className="profile-status">
          <div className="profile-main">
            <span className="profile-avatar">{(effectiveProfile.name ?? '?').charAt(0)}</span>
            <div>
              <div className="profile-name">{effectiveProfile.name ?? 'Connected'}</div>
              <div className="profile-id">{effectiveProfile.id}</div>
            </div>
          </div>
          <div className="profile-stats">
            <div className="profile-stat">
              <strong>{effectiveProfile.badges.length}</strong>
              <span>badges</span>
            </div>
            <div className="profile-stat">
              <strong>{effectiveProfile.points ?? '—'}</strong>
              <span>points</span>
            </div>
            <div className="profile-stat">
              <strong>{new Date(effectiveProfile.fetchedAt).toLocaleDateString()}</strong>
              <span>fetched</span>
            </div>
          </div>
          <div className="profile-actions">
            <span className="source-tag">
              {localProfile ? 'dari input browser' : serverProfile ? 'auto · GitHub Actions' : 'lokal'}
            </span>
            {localProfile && (
              <button className="btn-ghost" onClick={clearLocalProfile}>
                Reset browser cache
              </button>
            )}
          </div>
        </div>
      ) : (
        <div className="profile-empty">
          Belum ada profil terhubung — tempel link di atas lalu klik Connect.{' '}
          {serverProfile === null && (
            <span className="dim">
              Opsional: isi <code>web/public/profile-source.json</code> untuk auto-update via GitHub Actions.
            </span>
          )}
        </div>
      )}
    </section>
  )
}
