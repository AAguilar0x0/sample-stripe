import { type ClassValue, clsx } from 'clsx'
import { type PostgresError } from 'postgres'
import { twMerge } from 'tailwind-merge'

export const DAYS_IN_WEEK = 7
export const HOURS_IN_DAY = 1000 * 60 * 60 * 24

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

const serverUtils = {
  normalizeURL: (url: string) => {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = `https://${url}`
    }
    return url
  },
  isValidURL: (url: string) => {
    try {
      return url.startsWith('http://') || url.startsWith('https://')
    } catch {
      return false
    }
  },
  parseURLDomain: (url: string) => {
    try {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = `https://${url}`
      }

      const hostname = new URL(url).hostname.replace(/^www\./, '')

      return hostname.split('/')[0]
    } catch {
      return ''
    }
  },
  parseURLDomainFromEmail: (email: string) => {
    const domain = email.split('@')[1]
    return serverUtils.parseURLDomain(domain)
  },

  isPostgresError(error: unknown): error is PostgresError {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      typeof (error as any).code === 'string' &&
      'message' in error &&
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      typeof (error as any).message === 'string'
    )
  },
  trim(source: string, discriminator: string | ((val: string) => boolean)) {
    const discriminate = (val: string) => {
      if (typeof discriminator === 'string') {
        return val === discriminator
      } else {
        return discriminator(val)
      }
    }
    const len = source.length
    if (len === 0 || (!discriminate(source[0]) && !discriminate(source[len - 1]))) {
      return source
    }
    let startIndex = 0
    let endIndex = len
    while (startIndex < endIndex && discriminate(source[startIndex])) {
      startIndex++
    }
    while (endIndex > startIndex && discriminate(source[endIndex - 1])) {
      endIndex--
    }
    return source.slice(startIndex, endIndex)
  },
  isUUID: (value: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    return uuidRegex.test(value)
  },
  isProductionEnv: () => {
    return process.env.VERCEL_ENV === 'production'
  },
}

export default serverUtils
