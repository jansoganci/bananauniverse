/**
 * Dashboard Page - Protected Route Example
 *
 * Demonstrates:
 * - Server-side authentication check
 * - Fetching user data with credits
 * - Displaying user info and credit balance
 * - Calling Edge Functions
 */

import { createClient, getUserWithCredits } from '@/lib/supabase-server'
import { redirect } from 'next/navigation'
import { CreditBadge } from '@/components/CreditBadge'

export default async function DashboardPage() {
  // Check authentication (server-side)
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  // Fetch user data with credits
  const userData = await getUserWithCredits()

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="px-4 py-6 sm:px-0">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
              <p className="mt-1 text-sm text-gray-600">
                Welcome back, {user.email}
              </p>
            </div>
            <CreditBadge />
          </div>
        </div>

        {/* Stats Grid */}
        <div className="mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {/* Credit Balance Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-3xl">✨</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Credits Remaining
                    </dt>
                    <dd>
                      <div className="text-2xl font-bold text-gray-900">
                        {userData.credits_remaining}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div className="bg-gray-50 px-5 py-3">
              <div className="text-sm">
                <a
                  href="/credits/purchase"
                  className="font-medium text-blue-600 hover:text-blue-500"
                >
                  Buy more credits
                </a>
              </div>
            </div>
          </div>

          {/* Account Tier Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-3xl">👤</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Account Tier
                    </dt>
                    <dd>
                      <div className="text-2xl font-bold text-gray-900 capitalize">
                        {userData.tier || 'Free'}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div className="bg-gray-50 px-5 py-3">
              <div className="text-sm">
                <a
                  href="/settings/subscription"
                  className="font-medium text-blue-600 hover:text-blue-500"
                >
                  Upgrade plan
                </a>
              </div>
            </div>
          </div>

          {/* Quick Actions Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-3xl">🚀</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Quick Actions
                    </dt>
                    <dd className="mt-3 space-y-2">
                      <a
                        href="/generate"
                        className="block text-sm text-blue-600 hover:text-blue-500"
                      >
                        → Generate Video
                      </a>
                      <a
                        href="/history"
                        className="block text-sm text-blue-600 hover:text-blue-500"
                      >
                        → View History
                      </a>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="mt-8">
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900">
                Recent Activity
              </h3>
              <p className="mt-1 max-w-2xl text-sm text-gray-500">
                Your recent transactions and generations
              </p>
            </div>
            <div className="border-t border-gray-200 px-4 py-5 sm:px-6">
              <p className="text-sm text-gray-500">
                No recent activity. Start by generating your first video!
              </p>
            </div>
          </div>
        </div>

        {/* Sign Out */}
        <div className="mt-8">
          <form action="/auth/signout" method="post">
            <button
              type="submit"
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              Sign out
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
