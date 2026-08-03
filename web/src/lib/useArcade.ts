import { useCallback, useEffect, useMemo, useState } from 'react'
import { catalog } from '../generated/catalog'
import type { DoneOverride, ProfileData, QuotaTargets } from './types'
import { KEYS, load, save } from './storage'
import { matchBadgesToLabs, parseBadgeDate } from './matching'
import { fetchProfileViaProxy, fetchServerProfile, parseProfileId } from './profile'

const DEFAULT_TARGETS: QuotaTargets = { monthlyBadges: 15, pointsPerBadge: 0.5, legendTarget: 95 }

export type ArcadeState = ReturnType<typeof useArcade>

export function useArcade() {
  const [serverProfile, setServerProfile] = useState<ProfileData | null>(null)
  const [localProfile, setLocalProfile] = useState<ProfileData | null>(() =>
    load<ProfileData | null>(KEYS.profile, null),
  )
  const [profileUrl, setProfileUrl] = useState<string>(() => load<string>(KEYS.profileUrl, ''))
  const [connecting, setConnecting] = useState(false)
  const [connectError, setConnectError] = useState<string | null>(null)
  const [overrides, setOverrides] = useState<DoneOverride>(() => load<DoneOverride>(KEYS.overrides, {}))
  const [targets, setTargets] = useState<QuotaTargets>(() => ({ ...DEFAULT_TARGETS, ...load<Partial<QuotaTargets>>(KEYS.targets, {}) }))

  useEffect(() => {
    fetchServerProfile().then(setServerProfile)
  }, [])

  const effectiveProfile = localProfile ?? serverProfile

  const connectProfile = useCallback(
    async (raw: string) => {
      const id = parseProfileId(raw)
      if (!id) {
        setConnectError('Link tidak valid. Gunakan URL public profile seperti cloudskillsboost.google/public_profiles/<id>.')
        return
      }
      setConnecting(true)
      setConnectError(null)
      try {
        const url = raw.includes('cloudskillsboost') || raw.includes('skills.google') ? raw : `https://www.cloudskillsboost.google/public_profiles/${id}`
        const data = await fetchProfileViaProxy(url, id)
        setLocalProfile(data)
        save(KEYS.profile, data)
        setProfileUrl(url)
        save(KEYS.profileUrl, url)
      } catch (e) {
        setConnectError(e instanceof Error ? e.message : 'Gagal mengambil profil.')
      } finally {
        setConnecting(false)
      }
    },
    [],
  )

  const clearLocalProfile = useCallback(() => {
    setLocalProfile(null)
    save(KEYS.profile, null)
    setProfileUrl('')
    save(KEYS.profileUrl, '')
  }, [])

  const toggleDone = useCallback((labId: string, done: boolean) => {
    setOverrides((prev) => {
      const next = { ...prev, [labId]: done }
      save(KEYS.overrides, next)
      return next
    })
  }, [])

  const updateTargets = useCallback((patch: Partial<QuotaTargets>) => {
    setTargets((prev) => {
      const next = { ...prev, ...patch }
      save(KEYS.targets, next)
      return next
    })
  }, [])

  const stats = useMemo(() => {
    const badges = effectiveProfile?.badges ?? []
    const matches = matchBadgesToLabs(badges, catalog)

    const autoDone = new Set(matches.keys())
    const doneIds = new Set<string>()
    for (const lab of catalog) {
      const manual = overrides[lab.id]
      const done = manual !== undefined ? manual : autoDone.has(lab.id)
      if (done) doneIds.add(lab.id)
    }

    const now = new Date()
    const monthBadges = badges.filter((b) => {
      const d = parseBadgeDate(b.earnedAt)
      return d && d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()
    }).length

    const totalBadges = badges.length
    const pointsEstimate = Math.round(totalBadges * targets.pointsPerBadge * 10) / 10

    return { badges, matches, doneIds, autoDone, monthBadges, totalBadges, pointsEstimate }
  }, [effectiveProfile, overrides, targets])

  return {
    profileUrl,
    setProfileUrl,
    connecting,
    connectError,
    connectProfile,
    clearLocalProfile,
    effectiveProfile,
    serverProfile,
    localProfile,
    overrides,
    toggleDone,
    targets,
    updateTargets,
    stats,
  }
}
