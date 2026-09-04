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

async function callRpc<T>(env: Env, name: string) {
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      'content-type': 'application/json',
    },
    body: '{}',
  });

  if (!response.ok) throw new Error(`${name} failed: ${response.status}`);
  return (await response.json()) as T;
}

async function processWave(env: Env) {
  const insertedWaves = await callRpc<number>(env, 'ensure_draw_waves');
  if (insertedWaves > 0) {
    console.log('Draw waves materialized', { insertedWaves });
  }

  const invitations = await callRpc<DueInvitation[]>(env, 'process_due_wave');

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
