/**
 * Supabase Client for Browser/Client Components
 *
 * Use this in:
 * - Client Components (use client directive)
 * - Browser-side operations
 * - Real-time subscriptions
 *
 * Example:
 * ```tsx
 * 'use client'
 * import { supabase } from '@/lib/supabase-client'
 *
 * const { data } = await supabase.from('users').select('*')
 * ```
 */

import { createBrowserClient } from '@supabase/ssr'

export const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

/**
 * Auth Helpers
 */
export const auth = {
  /**
   * Sign in with email and password
   */
  signIn: async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    if (error) throw error
    return data
  },

  /**
   * Sign up with email and password
   */
  signUp: async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    })
    if (error) throw error
    return data
  },

  /**
   * Sign out
   */
  signOut: async () => {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
  },

  /**
   * Get current session
   */
  getSession: async () => {
    const { data, error } = await supabase.auth.getSession()
    if (error) throw error
    return data.session
  },

  /**
   * Get current user
   */
  getUser: async () => {
    const { data, error } = await supabase.auth.getUser()
    if (error) throw error
    return data.user
  },

  /**
   * Send password reset email
   */
  resetPassword: async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    })
    if (error) throw error
  },
}

/**
 * API Helpers (Call your Supabase Edge Functions)
 */
export const api = {
  /**
   * Call an Edge Function
   */
  invoke: async (functionName: string, body?: any) => {
    const { data, error } = await supabase.functions.invoke(functionName, {
      body,
    })
    if (error) throw error
    return data
  },

  /**
   * Update credits (add or deduct)
   */
  updateCredits: async (action: 'add' | 'deduct', amount: number, reason?: string) => {
    return api.invoke('update-credits', { action, amount, reason })
  },

  /**
   * Get current credit balance
   */
  getCredits: async () => {
    const user = await auth.getUser()
    if (!user) throw new Error('Not authenticated')

    const { data, error } = await supabase
      .from('users')
      .select('credits_remaining')
      .eq('id', user.id)
      .single()

    if (error) throw error
    return data.credits_remaining
  },

  /**
   * Generate video (example async job)
   */
  generateVideo: async (prompt: string, themeId: string) => {
    return api.invoke('generate-video', { prompt, theme_id: themeId })
  },
}
