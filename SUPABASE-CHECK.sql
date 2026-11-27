-- Read-only report of the database settings hello depends on. Changes nothing and returns no user data.
-- Run in the Supabase SQL Editor.
select 'rls' as kind, c.relname as object, case when c.relrowsecurity then 'enabled' else 'DISABLED' end as detail
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r'
union all
select 'policy', schemaname||'.'||tablename||' / '||policyname,
       cmd||' to '||array_to_string(roles,',')||' using ['||coalesce(qual,'-')||'] check ['||coalesce(with_check,'-')||']'
from pg_policies where schemaname='public' or (schemaname='storage' and tablename='objects')
union all
select 'function', p.proname, case when p.prosecdef then 'security definer' else 'security invoker' end
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
union all
select 'trigger on auth.users', t.tgname, pg_get_triggerdef(t.oid)
from pg_trigger t where t.tgrelid='auth.users'::regclass and not t.tgisinternal
union all
select 'realtime', schemaname||'.'||tablename, 'published' from pg_publication_tables where pubname='supabase_realtime'
union all
select 'bucket', id, 'public='||public::text||' limit='||coalesce(file_size_limit::text,'none') from storage.buckets
order by 1,2;
