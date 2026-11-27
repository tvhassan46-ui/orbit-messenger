# hello web push setup

Add these Vercel environment variables:
- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY (server-side only)
- VAPID_PUBLIC_KEY
- VAPID_PRIVATE_KEY
- PUSH_WEBHOOK_SECRET (long random value)
- VAPID_SUBJECT (mailto: contact address)

Run SUPABASE-SETUP.sql (it includes this table). The table on its own is:

    create table if not exists public.push_subscriptions (
      id bigint generated always as identity primary key,
      user_id uuid not null references auth.users(id) on delete cascade,
      endpoint text not null,
      subscription jsonb not null,
      created_at timestamptz not null default now(),
      unique(user_id,endpoint)
    );
    alter table public.push_subscriptions enable row level security;
    create policy "users manage own push subscriptions" on public.push_subscriptions for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);

Then Supabase Database -> Webhooks: create an INSERT webhook for public.messages pointing to https://orbit-messenger-psi.vercel.app/api/push-send (use a public domain: URLs behind Vercel Authentication, such as the git-main one, reject the webhook). Add header x-push-secret with value matching PUSH_WEBHOOK_SECRET. Send the webhook record payload.

On hello, sign in and enable notifications in Settings. Test from a second account. Delivery needs HTTPS, a supported browser, and the configured webhook.

VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY must be a matching pair; the app reads the public key from GET /api/push-subscribe.
The webhook response shows `sent` and `failed` counts, and failed delivery status codes appear in the Vercel function logs.
