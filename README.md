# Orbit Messenger — authentication upgrade

This branch replaces the local demo experience with a Supabase-backed starter. No demo users or sample conversations are seeded.

## Setup
1. Create a Supabase project.
2. Copy the Project URL and anon/publishable key from Project Settings → API.
3. Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` inside `index.html`. Never use the service-role key in browser code.
4. Run `supabase.sql` in Supabase SQL Editor.
5. Enable Email, Google, and Phone providers in Supabase Authentication. Configure Google OAuth credentials, redirect URLs (including your Vercel URL), and an SMS provider for OTP.
6. Deploy this branch to Vercel.

Included: email/password sign-in/signup, phone OTP, Google OAuth, profile directory, direct text messages, realtime updates.
Not yet included: attachments, profile editing, moderation/abuse controls, delivery/read receipts, full production security review.
