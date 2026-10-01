-- Prüft die Share-Tabelle: abgeleitete Spalten, Namensprüfung, Hüllen-Form und
-- die Mengenbegrenzung.
--
-- psql "$SUPABASE_DB_URL" -f verify-shares.sql

\pset pager off

\echo '== 1. Hüllen und die daraus abgeleiteten Spalten =='
-- Ohne Passwort: Nutzername + Schule
insert into public.shares
  (id, owner_username, school_number, display_name, label, searchable, is_global, envelopes)
values
  ('share-offen', 'blue sky river seven apple candle', '12345', 'Frau Müller',
   'Vertretungsplaene', true, false,
   '{"byUsername":{"v":1},"bySchool":{"v":1}}'::jsonb);

-- Mit Passwort: nur Passwort, damit weder Nutzername noch Schuldaten genuegen
insert into public.shares
  (id, owner_username, school_number, display_name, label, searchable, is_global, envelopes)
values
  ('share-gesichert', 'red moon water nine tiger mango', '12345', 'Herr Schmidt',
   'Krankentracking', true, false,
   '{"byPassword":{"v":1}}'::jsonb);

select id, has_password, unlockable_with_school
  from public.shares
 order by id;

\echo ''
\echo 'offen        -> has_password=f, unlockable_with_school=t  (Nutzername ODER Schule)'
\echo 'gesichert    -> has_password=t, unlockable_with_school=f  (nur Passwort)'

\echo ''
\echo '== 2. Ungueltige Hüllen werden abgelehnt =='
do $$
begin
  -- Leere Huelle: es waere nichts zu oeffnen
  begin
    insert into public.shares
      (id, owner_username, school_number, display_name, envelopes)
    values ('share-leer', 'x y z', '12345', 'Frau Test', '{}'::jsonb);
    raise notice 'FEHLER: leere Huelle akzeptiert';
  exception when check_violation then
    raise notice 'ok: leere Huelle abgelehnt';
  end;

  -- Unbekannter Huellenname: wuerde nie geoeffnet
  begin
    insert into public.shares
      (id, owner_username, school_number, display_name, envelopes)
    values ('share-fremd', 'x y z', '12345', 'Frau Test',
            '{"byAdmin":{"v":1}}'::jsonb);
    raise notice 'FEHLER: unbekannte Huelle akzeptiert';
  exception when check_violation then
    raise notice 'ok: unbekannte Huelle abgelehnt';
  end;

  -- Zu langer Anzeigename
  begin
    insert into public.shares
      (id, owner_username, school_number, display_name, envelopes)
    values ('share-lang', 'x y z', '12345', repeat('a', 41),
            '{"byUsername":{"v":1}}'::jsonb);
    raise notice 'FEHLER: zu langer Name akzeptiert';
  exception when check_violation then
    raise notice 'ok: zu langer Name abgelehnt';
  end;
end $$;

\echo ''
\echo '== 3. Der Name-Trigger greift auch bei direktem Setzen =='
-- Genau der Punkt, um den es geht: Die App prueft den Namen, aber ein
-- Aufrufer, der die Schnittstelle direkt anspricht, umgeht die App. Der
-- Trigger ist die zweite Instanz.
do $$
begin
  begin
    insert into public.shares
      (id, owner_username, school_number, display_name, envelopes)
    values ('share-beleidigend', 'x y z', '12345', 'Arschloch',
            '{"byUsername":{"v":1}}'::jsonb);
    raise notice 'FEHLER: anstoessender Name akzeptiert';
  exception when check_violation then
    raise notice 'ok: anstoessender Name abgelehnt (Trigger, nicht CHECK)';
  end;

  -- Auch nachtraeglich geaendert
  begin
    update public.shares set display_name = 'Scheisskopf' where id = 'share-offen';
    raise notice 'FEHLER: nachtraegliche Aenderung akzeptiert';
  exception when check_violation then
    raise notice 'ok: nachtraegliche Aenderung abgelehnt';
  end;
end $$;

\echo ''
\echo '== 4. Das Suchmenu zeigt nur die eigene Schulnummer =='
select '12345 sieht' as perspektive, s.display_name, s.label
  from public.shares s
 where s.school_number = '12345' and s.searchable
union all
select '99999 sieht', s.display_name, s.label
  from public.shares s
 where s.school_number = '99999' and s.searchable
order by 1, 2;

\echo '(99999 sieht nichts – die Zeile muss 0 haben)'

\echo ''
\echo '== 5. Kein suchbarer Share erscheint auch in der eigenen Schule =='
insert into public.shares
  (id, owner_username, school_number, display_name, label, searchable, is_global, envelopes)
values
  ('share-versteckt', 'green hill snow ten lion mango', '12345', 'Frau Heimlich',
   'Nur direkt', false, false, '{"byUsername":{"v":1}}'::jsonb);

select count(*) as sichtbar
  from public.shares
 where school_number = '12345'
   and searchable
   and owner_username = 'green hill snow ten lion mango';

\echo '(muss 0 sein)'

\echo ''
\echo '== 6. Ein globaler Share erscheint NICHT im Verzeichnis =='
-- Global heisst: von jeder Schule per Nutzername nutzbar. Nicht: ueberall
-- gelistet. Deshalb steht hier kein Filter auf is_global im Verzeichnis.
insert into public.shares
  (id, owner_username, school_number, display_name, label, searchable, is_global, envelopes)
values
  ('share-global', 'amber field wood two blue crane', '12345', 'Frau Ueberall',
   'Offen fuer alle', true, true, '{"byUsername":{"v":1}}'::jsonb);

select '12345 sieht' as perspektive, count(*) as anzahl
  from public.shares where school_number = '12345' and searchable
union all
select '77777 sieht', count(*)
  from public.shares where school_number = '77777' and searchable;

\echo '(77777 sieht 0 – global aendert nichts an der Sichtbarkeit)'
