export type FileKind = 'script' | 'config'

export interface LabFile {
  name: string
  kind: FileKind
  content: string
}

export interface LabVariable {
  prompt: string
  files: string[]
}

export interface Lab {
  id: string
  folder: string
  name: string
  code: string | null
  category: string
  description: string | null
  variables: LabVariable[]
  files: LabFile[]
  primaryFile: string
  runCommands: string[]
  readme: string | null
}

export interface Badge {
  name: string
  earnedAt: string | null
}

export interface ProfileData {
  id: string | null
  name: string | null
  points: number | null
  badges: Badge[]
  fetchedAt: string
}

export interface QuotaTargets {
  monthlyBadges: number
  pointsPerBadge: number
  legendTarget: number
}

export type DoneOverride = Record<string, boolean>

export type StatusFilter = 'all' | 'done' | 'todo'
