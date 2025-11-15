/**
 * Telegram Alert Helper
 * Purpose: Send notifications to Telegram
 */

export interface TelegramAlert {
  level: 'info' | 'warning' | 'error'
  title: string
  message: string
  metadata?: Record<string, any>
}

/**
 * Send alert to Telegram
 */
export async function sendTelegramAlert(alert: TelegramAlert): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN')
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID')

  if (!botToken || !chatId) {
    console.warn('Telegram not configured, skipping alert')
    return
  }

  // Choose emoji based on level
  const emoji = {
    info: 'ℹ️',
    warning: '⚠️',
    error: '🚨',
  }[alert.level]

  // Format message
  let text = `${emoji} *${alert.title}*\n\n${alert.message}`

  if (alert.metadata) {
    text += '\n\n*Details:*\n'
    for (const [key, value] of Object.entries(alert.metadata)) {
      text += `• ${key}: ${value}\n`
    }
  }

  text += `\n_${new Date().toISOString()}_`

  try {
    await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: 'Markdown',
      }),
    })
  } catch (error) {
    console.error('Failed to send Telegram alert:', error)
  }
}

/**
 * Quick alerts for common events
 */
export const TelegramAlerts = {
  purchase: (userId: string, productName: string, credits: number) =>
    sendTelegramAlert({
      level: 'info',
      title: 'Purchase Completed',
      message: `User purchased ${productName}`,
      metadata: { user_id: userId, credits_granted: credits },
    }),

  error: (endpoint: string, error: string, userId?: string) =>
    sendTelegramAlert({
      level: 'error',
      title: `Error in ${endpoint}`,
      message: error,
      metadata: userId ? { user_id: userId } : undefined,
    }),

  refund: (userId: string, transactionId: string, credits: number) =>
    sendTelegramAlert({
      level: 'warning',
      title: 'Refund Processed',
      message: `User refunded ${credits} credits`,
      metadata: { user_id: userId, transaction_id: transactionId },
    }),

  providerDown: (providerName: string, failures: number) =>
    sendTelegramAlert({
      level: 'error',
      title: 'Provider Down',
      message: `${providerName} has ${failures} consecutive failures`,
      metadata: { provider: providerName },
    }),
}
