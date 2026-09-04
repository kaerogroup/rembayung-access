interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  RESEND_API_KEY: string;
  APP_URL: string;
}

type DueInvitation = {
  wave_id: string;
  invitation_id: string;
  user_id: string;
  session_id: string;
  token_plain: string;
  expires_at: string;
};

async function processWave(env: Env) {
  const rpc = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/process_due_wave`, {
    method: 'POST',
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      'content-type': 'application/json',
    },
    body: '{}',
  });

  if (!rpc.ok) throw new Error(`process_due_wave failed: ${rpc.status}`);
  const invitations = (await rpc.json()) as DueInvitation[];

  // Skeleton only. Slice C will resolve the verified recipient email
  // server-side and send the invitation through Resend.
  for (const invitation of invitations) {
    console.log('Invitation ready', {
      invitationId: invitation.invitation_id,
      url: `${env.APP_URL}/invite/${invitation.token_plain}`,
    });
  }
}

export default {
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(processWave(env));
  },
};
