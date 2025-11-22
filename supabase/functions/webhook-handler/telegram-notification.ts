// ============================================
// TELEGRAM NOTIFICATION FOR IMAGE GENERATION
// ============================================

export async function sendTelegramGenerationNotification(data: {
  userId: string;
  deviceId: string;
  jobId: string;
  status: string;
}, supabase: any): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');

  if (!botToken || !chatId) {
    return; // Silently skip if not configured
  }

  // Get detailed job info from database
  let creditsRemaining = 'N/A';
  let modelType = 'Unknown';
  let aspectRatio = 'Unknown';
  let resolution = 'Standard';
  let numImages = 1;
  let creditCost = 1;
  let createdAt = '';
  let prompt = '';
  let actualUserId: string | null = null;
  let actualDeviceId: string | null = null;

  try {
    // Get job details including prompt
    const { data: jobData } = await supabase
      .from('job_results')
      .select('model_type, aspect_ratio, resolution, num_images, credit_cost, created_at, user_id, device_id')
      .eq('fal_job_id', data.jobId)
      .single();

    if (jobData) {
      modelType = jobData.model_type || 'nano-banana';
      aspectRatio = jobData.aspect_ratio || '1:1';
      resolution = jobData.resolution || 'Standard';
      numImages = jobData.num_images || 1;
      creditCost = jobData.credit_cost || 1;
      createdAt = jobData.created_at;
      actualUserId = jobData.user_id;
      actualDeviceId = jobData.device_id;
    }

    // Get prompt from job_history table
    const { data: historyData } = await supabase
      .from('job_history')
      .select('prompt')
      .eq('fal_job_id', data.jobId)
      .single();

    if (historyData && historyData.prompt) {
      prompt = historyData.prompt;
    }

    // Get user credits using actual user/device IDs from job
    if (actualUserId) {
      const { data: creditData } = await supabase
        .from('user_credits')
        .select('credits_remaining')
        .eq('user_id', actualUserId)
        .maybeSingle();

      if (creditData) {
        creditsRemaining = creditData.credits_remaining.toString();
      }
    } else if (actualDeviceId) {
      const { data: creditData } = await supabase
        .from('user_credits')
        .select('credits_remaining')
        .eq('device_id', actualDeviceId)
        .maybeSingle();

      if (creditData) {
        creditsRemaining = creditData.credits_remaining.toString();
      }
    }
  } catch (error) {
    // Ignore errors - just show what we have
  }

  const userDisplay = data.userId !== 'anonymous'
    ? `👤 User: \`${data.userId.substring(0, 8)}...\``
    : `📱 Device: \`${data.deviceId.substring(0, 8)}...\``;

  const statusEmoji = data.status === 'completed' ? '✅' : '❌';

  // Calculate processing time if we have created_at
  let processingTime = '';
  if (createdAt) {
    const startTime = new Date(createdAt);
    const endTime = new Date();
    const diffSeconds = Math.round((endTime.getTime() - startTime.getTime()) / 1000);
    processingTime = `   • Processing Time: ${diffSeconds}s\n`;
  }

  // Truncate prompt if too long (max 100 chars)
  let promptDisplay = '';
  if (prompt) {
    const truncatedPrompt = prompt.length > 100
      ? prompt.substring(0, 100) + '...'
      : prompt;
    promptDisplay = `\n**Prompt:**\n_"${truncatedPrompt}"_\n`;
  }

  const message = `🎨 **IMAGE GENERATED!**\n\n` +
    `${userDisplay}\n\n` +
    `**Generation Details:**\n` +
    `   • Model: \`${modelType}\`\n` +
    `   • Aspect Ratio: ${aspectRatio}\n` +
    `   • Resolution: ${resolution}\n` +
    `   • Images: ${numImages}\n` +
    processingTime +
    `   • Status: ${statusEmoji} **${data.status}**\n` +
    promptDisplay +
    `\n**Credits:**\n` +
    `   • Cost: -${creditCost} credit${creditCost > 1 ? 's' : ''}\n` +
    `   • Remaining: **${creditsRemaining} credits**\n\n` +
    `**Job:**\n` +
    `   • ID: \`${data.jobId.substring(0, 16)}...\`\n` +
    `   • Time: ${new Date().toLocaleString('en-US', {
      timeZone: 'UTC',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })} UTC`;

  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text: message,
      parse_mode: 'Markdown'
    })
  });

  if (!response.ok) {
    throw new Error(`Telegram API error: ${response.status}`);
  }
}
