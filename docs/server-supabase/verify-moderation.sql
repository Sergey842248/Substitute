-- Prüft die SQL-Umsetzung der Namensprüfung gegen dieselben Fälle, die der
-- Dart-Test in test/name_guard_test.dart abdeckt. Läuft gegen ein frisches
-- Schema, nicht in die App.

\pset pager off

\echo '== normalize_name =='
select
  public.normalize_name('Frau Muster')     as plain,
  public.normalize_name('Müller')           as umlaut,
  public.normalize_name('Scheiß')           as eszett,
  public.normalize_name('b1tch')            as leet,
  public.normalize_name('f-u-c-k')          as trenner,
  public.normalize_name('fuuuuuck')         as dehnung,
  public.normalize_name('O''Brien-Smith')   as zeichen;

\echo ''
\echo '== muss blockiert werden =='
select v.name, c.blocked, c.matched
  from (values
    ('Arschloch'), ('arschloch'), ('ARSCHLOCH'), ('Arsch loch'),
    ('a-r-s-c-h-l-o-c-h'), ('Scheißkopf'), ('Scheisskopf'), ('SCHEISS'),
    ('Dreckkerl'), ('Dumbsack'), ('Fotzenhocker'), ('Ficktack'),
    ('Ficker'), ('N1gger'), ('Nigg3r'), ('Faggot'), ('Fag'),
    ('Wichser'), ('Hurensohn'), ('Idiot'), ('Motherfucker'), ('Bastard'),
    ('Pornografie')
  ) as v(name)
  cross join lateral public.check_display_name(v.name) c
 order by c.blocked desc, v.name;

\echo '(alle Zeilen muessen blocked = t sein)'

\echo ''
\echo '== darf NICHT blockiert werden =='
select v.name, c.blocked, c.matched
  from (values
    ('Frau Muster'), ('Herr Schmidt'), ('Brückner'), ('Bass'),
    ('Klassenzimmer'), ('Dickmann'), ('Pohlmann'), ('Klug'), ('Fuchs'),
    ('Ostermann'), ('Gastmann'), ('Reimann'), ('Anna Bergmann'),
    ('Herr Müller-Schmidt'), ('Hürth'), ('Sahne'), ('Sexophon')
  ) as v(name)
  cross join lateral public.check_display_name(v.name) c
 order by c.blocked desc, v.name;

\echo '(alle Zeilen muessen blocked = f sein)'

\echo ''
\echo '== Grenzwerte des Anzeigenamens =='
select v.name, c.blocked, c.matched
  from (values (''), ('  '), ('A'), ('AB'), ('A'||repeat('b', 39)), ('A'||repeat('b', 40))
  ) as v(name)
  cross join lateral public.check_display_name(v.name) c;

\echo '(leer/zu kurz/zu lang muessen t sein)'
