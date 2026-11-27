import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  // The VAPID *public* key is meant for browsers. The shape check guarantees a private key is never returned.
  if (req.method === 'GET') {
    const publicKey = (process.env.VAPID_PUBLIC_KEY || '').trim();
    if (!/^B[A-Za-z0-9_-]{86}$/.test(publicKey)) return res.status(503).json({ error: 'Push is not configured' });
    return res.status(200).json({ publicKey });
  }
  if (req.method !== 'POST') return res.status(405).end();
  try {
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    if (!token) return res.status(401).json({ error: 'Unauthorized' });
    const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
    const { data: { user }, error } = await sb.auth.getUser(token);
    if (error || !user) return res.status(401).json({ error: 'Invalid session' });
    const subscription = req.body?.subscription;
    if (!subscription?.endpoint?.startsWith('https://') || !subscription?.keys?.p256dh || !subscription?.keys?.auth) {
      return res.status(400).json({ error: 'Invalid subscription' });
    }
    const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
    const { error: dbError } = await admin
      .from('push_subscriptions')
      .upsert({ user_id: user.id, endpoint: subscription.endpoint, subscription }, { onConflict: 'user_id,endpoint' });
    if (dbError) throw dbError;
    // One browser belongs to one account: stop sending it a previous user's notifications.
    const { error: cleanupError } = await admin
      .from('push_subscriptions')
      .delete()
      .eq('endpoint', subscription.endpoint)
      .neq('user_id', user.id);
    if (cleanupError) console.warn('push-subscribe cleanup:', cleanupError.message);
    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('push-subscribe:', e.message);
    return res.status(500).json({ error: 'Failed to save subscription' });
  }
}
