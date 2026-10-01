-- Prüft die Drosselung, mit der die Edge Functions arbeiten.
--
-- psql "$SUPABASE_DB_URL" -f verify-rate-limit.sql

\pset pager off

create or replace function pg_temp.check(
  p_label text, p_got boolean, p_want boolean
) returns void language plpgsql as $$
begin
  if p_got is distinct from p_want then
    raise exception 'FEHLER bei %: erwartet %, bekam %', p_label, p_want, p_got;
  end if;
  raise notice 'ok: % = %', p_label, p_got;
end;
$$;

\echo '== Fenster laeuft, Zaehler steigt, Limit greift genau =='
truncate public.rate_limit;
select public.bump_rate_limit('a', now() - interval '60 seconds', 3) as "1";
select public.bump_rate_limit('a', now() - interval '60 seconds', 3) as "2";
select public.bump_rate_limit('a', now() - interval '60 seconds', 3) as "3 (am Limit: noch erlaubt)";
select public.bump_rate_limit('a', now() - interval '60 seconds', 3) as "4 (abgelehnt)";

\echo ''
\echo '== Fenster abgelaufen: Zaehler beginnt neu =='
-- Ein Schluessel, der vor drei Stunden begonnen hat und bei 99 steht.
truncate public.rate_limit;
insert into public.rate_limit values ('alt', now() - interval '3 hours', 99);
select public.bump_rate_limit('alt', now() - interval '60 seconds', 3) as "muss true sein";

select bucket, hits from public.rate_limit order by bucket;
\echo '(hits muss 1 sein, nicht 100)'

\echo ''
\echo '== Danach wieder normal hochzaehlen =='
select public.bump_rate_limit('alt', now() - interval '60 seconds', 3) as "1 (true)";
select public.bump_rate_limit('alt', now() - interval '60 seconds', 3) as "2 (true)";
select public.bump_rate_limit('alt', now() - interval '60 seconds', 3) as "3 (true)";
select public.bump_rate_limit('alt', now() - interval '60 seconds', 3) as "4 (false)";

\echo ''
\echo '== Getrennte Schluessel, getrennte Zaehler =='
truncate public.rate_limit;
select public.bump_rate_limit('ip-1', now() - interval '60 seconds', 1) as "ip-1 #1 (true)";
select public.bump_rate_limit('ip-1', now() - interval '60 seconds', 1) as "ip-1 #2 (false)";
select public.bump_rate_limit('ip-2', now() - interval '60 seconds', 1) as "ip-2 #1 (true, eigener Zaehler)";

\echo ''
\echo '== Endauszug =='
select bucket, hits, window_started from public.rate_limit order by bucket;
