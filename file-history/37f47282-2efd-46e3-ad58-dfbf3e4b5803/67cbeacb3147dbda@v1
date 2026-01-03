// ============================================================================
// SESSION AUTHENTICATION HELPER
// Reusable auth checks for API endpoints
// Created for issues #83, #84, #85, #86
// ============================================================================

import { cookies } from 'next/headers';
import { prisma } from '@/lib/db';
import { logger } from '@/lib/logger';

export interface AuthResult {
  authenticated: boolean;
  userId: string | null;
  error?: string;
}

/**
 * Validate user authentication from cookie
 * Use this at the start of any protected API endpoint
 */
export async function validateAuth(): Promise<AuthResult> {
  try {
    const cookieStore = await cookies();
    // Check new cookie first, fallback to legacy cookie for existing users
    const userId = cookieStore.get('mirrorbuddy-user-id')?.value
      || cookieStore.get('convergio-user-id')?.value;

    if (!userId) {
      return {
        authenticated: false,
        userId: null,
        error: 'No authentication cookie',
      };
    }

    // Verify user exists in database
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });

    if (!user) {
      logger.warn('Auth failed: user not found', { userId });
      return {
        authenticated: false,
        userId: null,
        error: 'User not found',
      };
    }

    return {
      authenticated: true,
      userId,
    };
  } catch (error) {
    logger.error('Auth validation error', { error: String(error) });
    return {
      authenticated: false,
      userId: null,
      error: 'Auth validation failed',
    };
  }
}

/**
 * Validate that a session belongs to the authenticated user
 * Use for SSE endpoints that need session ownership verification
 *
 * Voice sessions (starting with 'voice-') are ephemeral and don't have
 * a database record, so we allow them for authenticated users.
 */
export async function validateSessionOwnership(
  sessionId: string,
  userId: string
): Promise<boolean> {
  try {
    // Voice sessions are ephemeral - allow for authenticated users
    // Format: voice-{maestroId}-{timestamp}
    if (sessionId.startsWith('voice-')) {
      logger.debug('Voice session validated', { sessionId, userId });
      return true;
    }

    // Sessions are stored as Conversations in our schema
    const conversation = await prisma.conversation.findFirst({
      where: {
        id: sessionId,
        userId,
      },
      select: { id: true },
    });

    return !!conversation;
  } catch (error) {
    logger.error('Session ownership check failed', { error: String(error) });
    return false;
  }
}

/**
 * Simple rate limiting by IP (in-memory, resets on restart)
 * For production, use Redis or similar
 */
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

export function checkRateLimit(
  key: string,
  maxRequests: number = 100,
  windowMs: number = 60000
): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return { allowed: true, remaining: maxRequests - 1 };
  }

  if (entry.count >= maxRequests) {
    return { allowed: false, remaining: 0 };
  }

  entry.count++;
  return { allowed: true, remaining: maxRequests - entry.count };
}
