/// Zugangsdaten des Sync-Servers.
///
/// ## Der Publishable Key ist öffentlich
///
/// `sb_publishable_…` ist ausdrücklich dafür gedacht, in eine App ausgeliefert
/// zu werden. Er ist ein Schlüssel *ohne* Rechte: Welche Zeile jemand lesen
/// darf, entscheidet allein die Row-Level-Security in der Datenbank. Deshalb
/// steht er hier im Klartext, und deshalb ist das kein Leak.
///
/// Gegenprobe dazu, ausgeführt gegen die echte Instanz:
///
/// ```
/// curl "…/rest/v1/shares" -H "apikey: <publishable key>"
/// → 401 permission denied for table shares
/// ```
///
/// ## Der Secret Key gehört hier nicht hin
///
/// `sb_secret_…` darf niemals in ein Repository, in ein App-Binary oder in
/// ein Log. Die Edge Functions bekommen ihn von Supabase automatisch als
/// Umgebungsvariable `SUPABASE_SERVICE_ROLE_KEY` – dort wird er nur
/// gebraucht, und niemand außerhalb von Supabase sieht ihn.
class SyncCredentials {
  const SyncCredentials._();

  /// Adresse des Sync-Projekts.
  ///
  /// Erkennbar an `.supabase.co`: Der Client stellt dann auf die
  /// Edge-Functions-Form um (`/functions/v1/…` mit Query-Parametern). Jede
  /// andere Adresse wird als der eigene Server behandelt (`/v1/…` mit
  /// Pfadbestandteilen). Damit bleiben beide Varianten nutzbar, ohne dass
  /// irgendwo eine Konfiguration gekippt werden muss.
  static const String defaultServerUrl =
      'https://socgdoyooyiupnmzuaox.supabase.co';

  /// Der öffentliche Schlüssel. Siehe Kommentar oben.
  static const String publishableKey =
      'sb_publishable_MQtaHWk6WqUlCYr9rHuabA_u26D9N8M';

  /// true, wenn [url] auf eine Supabase-Instanz zeigt.
  static bool isSupabase(Uri url) {
    final String host = url.host.toLowerCase();
    return host == 'supabase.co' || host.endsWith('.supabase.co');
  }
}
