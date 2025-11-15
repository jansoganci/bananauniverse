/**
 * Credit Badge - Display user's credit balance
 *
 * Real-time credit balance display that updates automatically.
 * Fetches from database and subscribes to changes.
 *
 * Usage:
 * ```tsx
 * import { CreditBadge } from '@/components/CreditBadge'
 *
 * <CreditBadge />
 * ```
 */

'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase-client'
import { useAuth } from './AuthProvider'

export function CreditBadge() {
  const { user } = useAuth()
  const [credits, setCredits] = useState<number | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!user) {
      setCredits(null)
      setLoading(false)
      return
    }

    // Fetch initial credits
    async function fetchCredits() {
      const { data, error } = await supabase
        .from('users')
        .select('credits_remaining')
        .eq('id', user!.id)
        .single()

      if (error) {
        console.error('Error fetching credits:', error)
        setLoading(false)
        return
      }

      setCredits(data.credits_remaining)
      setLoading(false)
    }

    fetchCredits()

    // Subscribe to real-time updates
    const channel = supabase
      .channel('credits-changes')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'users',
          filter: `id=eq.${user.id}`,
        },
        (payload: any) => {
          setCredits(payload.new.credits_remaining)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [user])

  if (loading) {
    return (
      <div className="px-3 py-1 bg-gray-100 rounded-full text-sm text-gray-500">
        Loading...
      </div>
    )
  }

  if (!user || credits === null) {
    return null
  }

  // Color based on credit level
  const getColorClass = () => {
    if (credits === 0) return 'bg-red-100 text-red-700'
    if (credits < 10) return 'bg-yellow-100 text-yellow-700'
    return 'bg-green-100 text-green-700'
  }

  return (
    <div className={`px-3 py-1 rounded-full text-sm font-medium ${getColorClass()}`}>
      {credits} {credits === 1 ? 'credit' : 'credits'}
    </div>
  )
}

/**
 * Compact version for headers/navbars
 */
export function CreditBadgeCompact() {
  const { user } = useAuth()
  const [credits, setCredits] = useState<number | null>(null)

  useEffect(() => {
    if (!user) return

    async function fetchCredits() {
      const { data } = await supabase
        .from('users')
        .select('credits_remaining')
        .eq('id', user!.id)
        .single()

      if (data) setCredits(data.credits_remaining)
    }

    fetchCredits()

    const channel = supabase
      .channel('credits-compact')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'users',
          filter: `id=eq.${user.id}`,
        },
        (payload: any) => setCredits(payload.new.credits_remaining)
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [user])

  if (!user) return null

  return (
    <span className="text-sm font-medium">
      {credits ?? '...'} ✨
    </span>
  )
}
