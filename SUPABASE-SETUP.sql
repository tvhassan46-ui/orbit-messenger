-- hello Supabase schema/bootstrap. Run in the Supabase SQL Editor. Safe to run again.
-- It creates anything missing, never deletes rows, and replaces this app's policies and functions.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now()
);
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.message_reads (
  message_id bigint not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create table if not exists public.call_signals (
  id uuid primary key default gen_random_uuid(),
  caller_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  offer jsonb not null,
  answer jsonb,
  status text not null default 'ringing' check(status in ('ringing','accepted','declined','ended')),
  video boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.call_candidates (
  id bigint generated always as identity primary key,
  call_id uuid not null references public.call_signals(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  candidate jsonb not null,
  created_at timestamptz not null default now()
);
create table if not exists public.push_subscriptions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  subscription jsonb not null,
  created_at timestamptz not null default now(),
  unique(user_id,endpoint)
);

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;
alter table public.call_signals enable row level security;
alter table public.call_candidates enable row level security;
alter table public.push_subscriptions enable row level security;

create or replace function public.is_conversation_member(cid uuid, uid uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=uid)
$$;
grant execute on function public.is_conversation_member(uuid,uuid) to authenticated;

-- Recreate policies safely on reruns.
drop policy if exists "profiles visible to authenticated" on public.profiles;
create policy "profiles visible to authenticated" on public.profiles for select to authenticated using (true);
drop policy if exists "profile owner insert" on public.profiles;
create policy "profile owner insert" on public.profiles for insert to authenticated with check (auth.uid()=id);
drop policy if exists "profile owner update" on public.profiles;
create policy "profile owner update" on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id);

drop policy if exists "members view conversations" on public.conversations;
create policy "members view conversations" on public.conversations for select to authenticated using (public.is_conversation_member(id,auth.uid()));
drop policy if exists "members view membership" on public.conversation_members;
create policy "members view membership" on public.conversation_members for select to authenticated using (user_id=auth.uid() or public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists "members insert membership" on public.conversation_members;
-- No direct inserts: the former policy let any signed-in user add themselves to any conversation
-- whose id they knew. Membership is created only by create_direct_conversation() below.

drop policy if exists "members read messages" on public.messages;
create policy "members read messages" on public.messages for select to authenticated using (public.is_conversation_member(messages.conversation_id,auth.uid()));
drop policy if exists "members send messages" on public.messages;
create policy "members send messages" on public.messages for insert to authenticated with check (sender_id=auth.uid() and public.is_conversation_member(messages.conversation_id,auth.uid()));
drop policy if exists "members read receipts" on public.message_reads;
create policy "members read receipts" on public.message_reads for select to authenticated using (user_id=auth.uid() or exists(select 1 from public.messages msg join public.conversation_members m on m.conversation_id=msg.conversation_id where msg.id=message_reads.message_id and m.user_id=auth.uid()));
drop policy if exists "own read receipts" on public.message_reads;
create policy "own read receipts" on public.message_reads for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.messages msg where msg.id=message_reads.message_id and public.is_conversation_member(msg.conversation_id,auth.uid())));
drop policy if exists "update own read receipts" on public.message_reads;
create policy "update own read receipts" on public.message_reads for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid() and exists(select 1 from public.messages msg where msg.id=message_reads.message_id and public.is_conversation_member(msg.conversation_id,auth.uid())));

drop policy if exists "call participants view" on public.call_signals;
create policy "call participants view" on public.call_signals for select to authenticated using (caller_id=auth.uid() or recipient_id=auth.uid());
drop policy if exists "caller creates call" on public.call_signals;
-- Only people who already share a conversation can ring each other.
create policy "caller creates call" on public.call_signals for insert to authenticated with check (caller_id=auth.uid() and recipient_id<>auth.uid() and exists(select 1 from public.conversation_members a join public.conversation_members b on b.conversation_id=a.conversation_id where a.user_id=auth.uid() and b.user_id=call_signals.recipient_id));
drop policy if exists "participants update call" on public.call_signals;
create policy "participants update call" on public.call_signals for update to authenticated using (caller_id=auth.uid() or recipient_id=auth.uid()) with check (caller_id=auth.uid() or recipient_id=auth.uid());
drop policy if exists "call participants candidates" on public.call_candidates;
create policy "call participants candidates" on public.call_candidates for select to authenticated using (exists(select 1 from public.call_signals c where c.id=call_candidates.call_id and (c.caller_id=auth.uid() or c.recipient_id=auth.uid())));
drop policy if exists "participants add candidates" on public.call_candidates;
create policy "participants add candidates" on public.call_candidates for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.call_signals c where c.id=call_candidates.call_id and (c.caller_id=auth.uid() or c.recipient_id=auth.uid())));

drop policy if exists "own push subscriptions" on public.push_subscriptions;
create policy "own push subscriptions" on public.push_subscriptions for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.create_direct_conversation(other_user uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare existing_id uuid; new_id uuid;
begin
 if auth.uid() is null or other_user is null or other_user=auth.uid() then raise exception 'Invalid recipient'; end if;
 -- Serialise per pair so two simultaneous taps cannot create duplicate chats.
 perform pg_advisory_xact_lock(hashtextextended(least(auth.uid(),other_user)::text||greatest(auth.uid(),other_user)::text,0));
 select c.id into existing_id from public.conversations c
 join public.conversation_members a on a.conversation_id=c.id and a.user_id=auth.uid()
 join public.conversation_members b on b.conversation_id=c.id and b.user_id=other_user
 group by c.id limit 1;
 if existing_id is not null then return existing_id; end if;
 insert into public.conversations default values returning id into new_id;
 insert into public.conversation_members(conversation_id,user_id) values(new_id,auth.uid()),(new_id,other_user);
 return new_id;
end $$;
revoke execute on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

-- Lets the sign-up form check a username before the visitor has a session.
create or replace function public.username_available(candidate text)
returns boolean language sql stable security definer set search_path=public as $$
  select not exists(select 1 from public.profiles where lower(username)=lower(candidate))
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Realtime publication membership (ignore if already included).
do $$ begin
 alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when others then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.call_signals;
exception when duplicate_object then null; when others then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.call_candidates;
exception when duplicate_object then null; when others then null; end $$;

-- Create the media bucket. Policies limit each user to their own folder.
insert into storage.buckets(id,name,public) values('messages-media','messages-media',true) on conflict(id) do nothing;
-- Match the app's limits (only filled in if you have not set your own).
update storage.buckets set file_size_limit=20971520 where id='messages-media' and file_size_limit is null;
update storage.buckets set allowed_mime_types=array['image/jpeg','image/png','image/gif','image/webp','image/heic','image/heif','image/avif','video/*','audio/*'] where id='messages-media' and allowed_mime_types is null;
drop policy if exists "media public read" on storage.objects;
create policy "media public read" on storage.objects for select using (bucket_id='messages-media');
drop policy if exists "media user upload" on storage.objects;
create policy "media user upload" on storage.objects for insert to authenticated with check (bucket_id='messages-media' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "media user delete" on storage.objects;
create policy "media user delete" on storage.objects for delete to authenticated using (bucket_id='messages-media' and (storage.foldername(name))[1]=auth.uid()::text);
