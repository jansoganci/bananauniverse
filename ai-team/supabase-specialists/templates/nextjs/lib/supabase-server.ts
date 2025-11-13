/**
 * Supabase Client for Server Components/Actions
 *
 * Use this in:
 * - Server Components (default in App Router)
 * - Server Actions
 * - Route Handlers (app/api/*)
 *
 * Example:
 * ```tsx
 * import { createClient } from '@/lib/supabase-server'
 *
 * export default async function Page() {
 *   const supabase = createClient()
 *   const { data } = await supabase.from('users').select('*')
 *   return <div>{data}</div>
 * }
 * ```
 */

import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { cookies } from 'next/headers'

export function createClient() {
  const cookieStore = cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        },
        set(name: string, value: string, options: CookieOptions) {
          try {
            cookieStore.set({ name, value, ...options })
          } catch (error) {
            // The `set` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
        remove(name: string, options: CookieOptions) {
          try {
            cookieStore.set({ name, value: '', ...options })
          } catch (error) {
            // The `delete` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
      },
    }
  )
}

/**
 * Get current user (server-side)
 */
export async function getUser() {
  const supabase = createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error) {
    console.error('Error fetching user:', error)
    return null
  }

  return user
}

/**
 * Require authentication (server-side)
 * Throws error if not authenticated - use in Server Actions
 */
export async function requireAuth() {
  const user = await getUser()

  if (!user) {
    throw new Error('Unauthorized: Please sign in')
  }

  return user
}

/**
 * Get user with credits (common pattern)
 */
export async function getUserWithCredits() {
  const user = await requireAuth()

  const supabase = createClient()
  const { data, error } = await supabase
    .from('users')
    .select('id, email, credits_remaining, tier')
    .eq('id', user.id)
    .single()

  if (error) throw error

  return data
}
