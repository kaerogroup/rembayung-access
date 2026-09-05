interface Env {
  SUPABASE_URL: string;
  SUPABASE_SECRET_KEY: string;
  RESEND_API_KEY?: string;
  RESEND_FROM_EMAIL?: string;
  RESEND_TEST_RECIPIENT?: string;
  APP_BASE_URL?: string;
}

type DueInvitation = {
  wave_id: string;
  invitation_id: string;
  user_id: string;
  session_id: string;
  token_plain: string;
  expires_at: string;
};

type ClaimedDelivery = {
  delivery_id: string;
  invitation_id: string;
  recipient_email: string;
  session_title: string;
  invitation_token: string;
  expires_at: string;
  attempt_count: number;
};

type ResendResponse = {
  id?: string;
};

async function callRpc<T>(env: Env, name: string, body: Record<string, unknown> = {}) {
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: env.SUPABASE_SECRET_KEY,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(`${name} failed: ${response.status} ${responseText.slice(0, 500)}`);
  }

  return JSON.parse(responseText) as T;
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function invitationUrl(env: Env, token: string) {
  const baseUrl = env.APP_BASE_URL!.replace(/\/$/, '');
  return `${baseUrl}/invitation?token=${encodeURIComponent(token)}`;
}

async function sendResendInvitation(env: Env, delivery: ClaimedDelivery) {
  const url = invitationUrl(env, delivery.invitation_token);
  const sessionTitle = escapeHtml(delivery.session_title);
  const safeUrl = escapeHtml(url);
  const recipientEmail = env.RESEND_TEST_RECIPIENT ?? delivery.recipient_email;

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `invitation/${delivery.invitation_id}`,
    },
    body: JSON.stringify({
      from: env.RESEND_FROM_EMAIL,
      to: [recipientEmail],
      subject: `Jemputan Rembayung — ${delivery.session_title}`,
      html: [
        '<p>Anda telah dipilih untuk meneruskan tempahan.</p>',
        `<p><strong>${sessionTitle}</strong></p>`,
        `<p><a href="${safeUrl}">Buka jemputan Rembayung</a></p>`,
        '<p>Jemputan ini mempunyai tempoh sah terhad. Jangan kongsikan pautan ini.</p>',
      ].join(''),
    }),
  });

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(`Resend failed: ${response.status} ${responseText.slice(0, 500)}`);
  }

  const payload = JSON.parse(responseText) as ResendResponse;
  if (!payload.id) {
    throw new Error('Resend succeeded without a provider message id');
  }

  return payload.id;
}

async function processWave(env: Env) {
  const insertedWaves = await callRpc<number>(env, 'ensure_draw_waves');
  if (insertedWaves > 0) {
    console.log('Draw waves materialized', { insertedWaves });
  }

  const invitations = await callRpc<DueInvitation[]>(env, 'process_due_wave');

  // Never log invitation plaintext tokens.
  for (const invitation of invitations) {
    console.log('Invitation issued', {
      invitationId: invitation.invitation_id,
      sessionId: invitation.session_id,
      waveId: invitation.wave_id,
      expiresAt: invitation.expires_at,
    });
  }
}

async function drainEmailDeliveries(env: Env) {
  const expiredCount = await callRpc<number>(env, 'expire_email_deliveries');
  if (expiredCount > 0) {
    console.log('Expired invitation deliveries retired', { expiredCount });
  }

  if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL || !env.APP_BASE_URL) {
    console.log('Invitation email delivery inactive: Resend production configuration is incomplete');
    return;
  }

  for (let processed = 0; processed < 10; processed += 1) {
    const claims = await callRpc<ClaimedDelivery[]>(env, 'claim_pending_email_delivery');
    const delivery = claims[0];

    if (!delivery) {
      return;
    }

    try {
      const providerMessageId = await sendResendInvitation(env, delivery);
      const completed = await callRpc<boolean>(env, 'complete_email_delivery', {
        p_delivery_id: delivery.delivery_id,
        p_provider_message_id: providerMessageId,
      });

      if (!completed) {
        throw new Error('Delivery completion was not acknowledged by the outbox');
      }

      console.log('Invitation email sent', {
        deliveryId: delivery.delivery_id,
        invitationId: delivery.invitation_id,
        attemptCount: delivery.attempt_count,
        testRecipientOverride: Boolean(env.RESEND_TEST_RECIPIENT),
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown delivery failure';

      try {
        await callRpc<boolean>(env, 'fail_email_delivery', {
          p_delivery_id: delivery.delivery_id,
          p_error: message,
        });
      } catch (recordError) {
        console.error('Failed to record invitation email failure', {
          deliveryId: delivery.delivery_id,
          invitationId: delivery.invitation_id,
          error: recordError instanceof Error ? recordError.message : 'unknown outbox failure',
        });
      }

      console.error('Invitation email delivery failed', {
        deliveryId: delivery.delivery_id,
        invitationId: delivery.invitation_id,
        attemptCount: delivery.attempt_count,
        error: message,
      });
    }
  }
}

async function processScheduled(env: Env) {
  await processWave(env);
  await drainEmailDeliveries(env);
}

export default {
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(processScheduled(env));
  },
};
