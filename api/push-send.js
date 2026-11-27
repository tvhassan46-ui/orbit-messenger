import webpush from 'web-push';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  if (!process.env.PUSH_WEBHOOK_SECRET || req.headers['x-push-secret'] !== process.env.PUSH_WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  try {
    const msg = req.body?.record;
    if (!msg?.conversation_id || !msg?.sender_id) return res.status(400).json({ error: 'Expected webhook message record' });
    const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
    const { data: members, error } = await sb.from('conversation_members').select('user_id').eq('conversation_id', msg.conversation_id);
    if (error) throw error;
    const recipients = (members || []).map((x) => x.user_id).filter((id) => id !== msg.sender_id);
    if (!recipients.length) return res.status(200).json({ sent: 0, failed: 0 });
    const { data: sender } = await sb.from('profiles').select('display_name,username').eq('id', msg.sender_id).maybeSingle();
    let body = String(msg.content || 'New message').slice(0, 120);
    if (body.startsWith('MEDIA|')) body = 'Sent you a media message';
    if (body.startsWith('STICKER|')) body = 'Sent you a sticker';
    webpush.setVapidDetails(process.env.VAPID_SUBJECT || 'mailto:hello@example.com', process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
    const { data: subs, error: subErr } = await sb.from('push_subscriptions').select('user_id,subscription').in('user_id', recipients);
    if (subErr) throw subErr;
    let sent = 0;
    let failed = 0;
    await Promise.all((subs || []).map(async (s) => {
      try {
        await webpush.sendNotification(s.subscription, JSON.stringify({
          title: sender?.display_name || sender?.username || 'New message',
          body,
          tag: msg.conversation_id,
          url: '/'
        }));
        sent++;
      } catch (e) {
        failed++;
        console.warn('push-send delivery failed with status', e.statusCode || 'unknown');
        if (e.statusCode === 404 || e.statusCode === 410) {
          await sb.from('push_subscriptions').delete().eq('user_id', s.user_id).eq('endpoint', s.subscription.endpoint);
        }
      }
    }));
    return res.status(200).json({ sent, failed });
  } catch (e) {
    console.error('push-send:', e.message);
    return res.status(500).json({ error: 'Push sending failed' });
  }
}
