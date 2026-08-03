import type { ArcadeState } from '../lib/useArcade'

interface ProfileCardProps {
  arcade: ArcadeState
}

export function ProfileCard({ arcade }: ProfileCardProps) {
  const { profileUrl, setProfileUrl, connecting, connectError, connectProfile, clearLocalProfile, effectiveProfile, localProfile } = arcade

  return (
    <section className="card">
      <h2 className="card-title">Google Skills Profile</h2>
      <p className="card-hint">
        Tempel public profile URL kamu. Badge diambil langsung dari Google Skills dan tersimpan di browser ini.
      </p>

      <div className="field-row">
        <input
          type="text"
          className="field"
          value={profileUrl}
          onChange={(e) => setProfileUrl(e.target.value)}
          placeholder="cloudskillsboost.google/public_profiles/…"
          spellCheck={false}
        />
        <button className="btn" onClick={() => connectProfile(profileUrl)} disabled={connecting}>
          {connecting ? 'Menghubungkan' : 'Connect'}
        </button>
      </div>

      {connectError && <p className="form-error">{connectError}</p>}

      {effectiveProfile ? (
        <div className="profile-status">
          <div className="profile-row">
            <span className="avatar">{effectiveProfile.name ? effectiveProfile.name.charAt(0) : 'G'}</span>
            <div className="profile-id">
              <div className="profile-name">{effectiveProfile.name ?? 'Terhubung'}</div>
              <div className="profile-sub">{effectiveProfile.id}</div>
            </div>
            <span className="source-tag">{localProfile ? 'dari input' : 'auto · Actions'}</span>
          </div>
          <div className="profile-metrics">
            <div>
              <strong>{effectiveProfile.badges.length}</strong>
              <span>badges</span>
            </div>
            <div>
              <strong>{effectiveProfile.points ?? '—'}</strong>
              <span>points</span>
            </div>
            <div>
              <strong>{new Date(effectiveProfile.fetchedAt).toLocaleDateString()}</strong>
              <span>terakhir sync</span>
            </div>
          </div>
          {localProfile && (
            <button className="text-btn" onClick={clearLocalProfile}>
              Reset data browser
            </button>
          )}
        </div>
      ) : (
        <p className="empty-note">
          Belum terhubung. Opsional: isi <code>web/public/profile-source.json</code> untuk auto-update via GitHub
          Actions tiap 12 jam.
        </p>
      )}
    </section>
  )
}
