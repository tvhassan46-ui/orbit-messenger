create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,display_name text not null default 'Member',created_at timestamptz not null default now());
create table if not exists public.messages(id bigint generated always as identity primary key,sender_id uuid not null references public.profiles(id) on delete cascade,receiver_id uuid not null references public.profiles(id) on delete cascade,content text not null check(char_length(content) between 1 and 4000),created_at timestamptz not null default now());
alter table public.profiles enable row level security;alter table public.messages enable row level security;
create policy "Authenticated profile directory" on public.profiles for select to authenticated using(true);
create policy "Create own profile" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "Update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "Read own direct messages" on public.messages for select to authenticated using(sender_id=auth.uid() or receiver_id=auth.uid());
create policy "Send as self" on public.messages for insert to authenticated with check(sender_id=auth.uid());
alter publication supabase_realtime add table public.messages;