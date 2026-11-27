# hello

A black-and-white messaging web app (repository name: `orbit-messenger`).

- `index.html`: the whole front end (vanilla HTML, CSS and JavaScript, supabase-js v2 from its CDN)
- `api/`: Vercel functions for web push
- `sw.js`, `manifest.json`: installable app shell and push handler
- `SUPABASE-SETUP.sql`: tables, Row Level Security, functions, realtime and storage
- `SUPABASE-CHECK.sql`: read-only report of the live database settings
- `PUSH-SETUP.md`: notification setup

## Setup

1. Supabase SQL Editor: run `SUPABASE-SETUP.sql`.
2. Supabase Authentication, URL Configuration: set the Site URL to the public production URL and add it (with `/**`) to Redirect URLs. Confirmation and password reset links use these.
3. Supabase Authentication, SMTP: configure custom SMTP. The built-in sender only mails your own team members and is heavily rate limited.
4. Deploy on Vercel (no build step).

## Check before deploying

    node scripts/check.mjs

## Known limits

- Direct chats only; no group chats.
- Messages are not end-to-end encrypted. The media bucket is public, so anyone holding a file's link can open it.
- Calls use a public STUN server only. Some mobile networks also need a TURN server.

## Credits

Interface elements from Uiverse.io. See `THIRD-PARTY-NOTICES.md`.
