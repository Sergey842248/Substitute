-- Prüft die Constraints und Trigger an echten Zeilen. Erwartet eine
-- Instanz, auf der schema.sql bereits gelaufen ist.
--
-- psql "$SUPABASE_DB_URL" -f verify-constraints.sql

\pset pager off

\echo '== 1. Ein gültiger Snapshot lässt sich einfuegen =='
insert into public.chain_snapshots
  (chain_id, device_id, device_name, updated_at, includes_settings, envelope)
values
  ('chain-aaa', 'device-1', 'Pixel 8', now(), true,
   '{"v":1,"iv":"aXY=","ct":"Y2lwaGVy","mac":"bWFj","kdf":{"alg":"pbkdf2-sha256"}}');

\echo '== 2. Ungueltige Bezeichner werden abgelehnt =='
do $$
begin
  -- Alle Faelle unten brauchen eine * Gueltige * Huelle: Sonst greift zuerst
  -- der Form-Check und man prueft die falsche Constraint.
  -- Pfadverschleifung: duerfte niemals in einem Dateinamen landen.
  begin
    insert into public.chain_snapshots (chain_id, device_id, envelope)
    values ('../../etc/passwd', 'device-1',
            '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb);
    raise notice 'FEHLER: Pfad wurde akzeptiert';
  exception when check_violation then
    raise notice 'ok: Pfad abgelehnt';
  end;

  -- Laengengrenze
  begin
    insert into public.chain_snapshots (chain_id, device_id, device_name, envelope)
    values ('chain-bbb', 'device-1', repeat('x', 61),
            '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb);
    raise notice 'FEHLER: zu langer Geraetename akzeptiert';
  exception when check_violation then
    raise notice 'ok: Geraetename zu lang abgelehnt';
  end;

  -- Huellen-Form: ein Feld fehlt
  begin
    insert into public.chain_snapshots (chain_id, device_id, envelope)
    values ('chain-bbb', 'device-1', '{"v":1,"iv":"aXY=","ct":"Y2lwaGVy"}'::jsonb);
    raise notice 'FEHLER: unvollstaendige Huelle akzeptiert';
  exception when check_violation then
    raise notice 'ok: unvollstaendige Huelle abgelehnt';
  end;
end $$;

\echo '== 3. Ein Gerät kann keinen zweiten Snapshot anlegen =='
do $$
begin
  begin
    insert into public.chain_snapshots (chain_id, device_id, envelope)
    values ('chain-aaa', 'device-1',
            '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb);
    raise notice 'FEHLER: Duplikat akzeptiert';
  exception when unique_violation then
    raise notice 'ok: Duplikat abgelehnt (unique_violation)';
  end;
end $$;

\echo ''
\echo '== 4. Die Gerätegrenze greift genau am Limit =='
-- Limits.maxDevicesPerChain ist 12: die ersten 12 Geraete muessen durchgehen,
-- das 13. nicht. Der Trigger zaehlt die bestehenden Zeilen, bevor die neue
-- eingefuegt wird, deshalb wird bei 12 vorhandenen abgebrochen.
insert into public.chain_snapshots (chain_id, device_id, envelope)
select 'chain-limit', 'device-' || n,
       '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb
  from generate_series(1, 11) n;

-- Das 12. Geraet muss noch funktionieren.
insert into public.chain_snapshots (chain_id, device_id, envelope)
values ('chain-limit', 'device-12',
        '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb);

select count(*) as geraete_in_der_kette
  from public.chain_snapshots
 where chain_id = 'chain-limit';

-- Das 13. muss scheitern.
do $$
begin
  begin
    insert into public.chain_snapshots (chain_id, device_id, envelope)
    values ('chain-limit', 'device-13',
            '{"v":1,"iv":"a","ct":"b","mac":"c","kdf":{}}'::jsonb);
    raise notice 'FEHLER: 13. Geraet akzeptiert';
  exception when check_violation then
    raise notice 'ok: 13. Geraet abgelehnt (Limit 12)';
  end;
end $$;

-- Und ein bestehendes Geraet muss sich erneuern koennen, ohne dass der
-- Trigger zaehlt: sonst waere Sync in einer voll besetzten Kette fuer alle
-- vorhandenen Geraete tot. Der Weg dahin ist ein Upsert – so ruft es die App
-- auf, und so muss es der Server tun.
insert into public.chain_snapshots (chain_id, device_id, device_name, envelope)
values ('chain-limit', 'device-1', 'Erneuert',
        '{"v":1,"iv":"a","ct":"neu","mac":"c","kdf":{}}'::jsonb)
on conflict (chain_id, device_id) do update
   set device_name = excluded.device_name,
       envelope    = excluded.envelope;

select count(*) as geraete_nach_erneuerung,
       max(device_name) as geraet_1_name
  from public.chain_snapshots
 where chain_id = 'chain-limit';

\echo '(12 Zeilen, device-1 heisst jetzt "Erneuert")'

\echo ''
\echo '== 5. Abgeleitete Spalten =='
select id, has_password, unlockable_with_school
  from public.shares
 order by id;

\echo ''
\echo '== 6. Ersetzen statt verdoppeln (Upsert) =='
insert into public.chain_snapshots
  (chain_id, device_id, device_name, updated_at, includes_settings, envelope)
values
  ('chain-aaa', 'device-1', 'Neues Geraet', now(), false,
   '{"v":1,"iv":"aXY=","ct":"eA==","mac":"bWFj","kdf":{"alg":"pbkdf2-sha256"}}')
on conflict (chain_id, device_id) do update
  set device_name    = excluded.device_name,
      updated_at     = excluded.updated_at,
      envelope       = excluded.envelope,
      includes_settings = excluded.includes_settings;

select chain_id, device_id, device_name,
       count(*) over (partition by chain_id, device_id) as zeilen
  from public.chain_snapshots
 where chain_id = 'chain-aaa';

\echo '(zeilen muss 1 sein – ein Geraet, ein Snapshot)'
