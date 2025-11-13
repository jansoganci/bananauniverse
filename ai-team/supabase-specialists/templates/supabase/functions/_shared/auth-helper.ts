/**
 * Auth Helper
 * Purpose: Extract and validate user from Supabase Auth JWT
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface AuthenticatedUser {
  id: string
  email?: string
}

/**
 * Get authenticated user from request
 * @param req - HTTP request with Authorization header
 * @returns User ID if valid, throws error if invalid
 */
export async function getAuthenticatedUser(req: Request): Promise<AuthenticatedUser> {
  const authHeader = req.headers.get('Authorization')

  if (!authHeader) {
    throw new Error('Missing Authorization header')
  }

  // Extract Bearer token
  const token = authHeader.replace('Bearer ', '')

  // Create Supabase client to verify JWT
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  )

  // Verify JWT and get user
  const {
    data: { user },
    error,
  } = await supabaseClient.auth.getUser(token)

  if (error || !user) {
    throw new Error('Invalid or expired token')
  }

  return {
    id: user.id,
    email: user.email,
  }
}

/**
 * Get user from request or throw 401 error
 * Use this at the start of protected endpoints
 */
export async function requireAuth(req: Request): Promise<AuthenticatedUser> {
  try {
    return await getAuthenticatedUser(req)
  } catch (error) {
    throw new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    )
  }
}
