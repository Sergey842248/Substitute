import 'dart:async';
import 'dart:io';

import 'package:substitute_sync_server/src/api.dart';
import 'package:substitute_sync_server/src/store.dart';

/// Startet den Sync-Server.
///
/// Aufruf in der Praxis:
///
/// ```sh
/// PORT=8384 DATA_DIR=/var/lib/substitute-sync \
///   dart run bin/server.dart
/// ```
///
/// Der Prozess beendet sich bei SIGTERM sauber, damit systemd ihn als
/// heruntergefahren verbucht und der Nginx nicht kurzzeitig auf einen
/// geschlossenen Port zeigt.
Future<void> main(List<String> arguments) async {
  final Map<String, String> options = _parseArguments(arguments);

  final int port = int.tryParse(options['port'] ?? '') ?? 8384;
  final String dataDir = options['data'] ?? '/var/lib/substitute-sync';
  final String? apiToken = options['token']?.isEmpty ?? true ? null : options['token'];
  final String bind = options['bind'] ?? '127.0.0.1';

  final Store store = Store(Directory(dataDir));
  await store.open();

  final SyncApi api = SyncApi(store, apiToken: apiToken);

  final HttpServer server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port,
    shared: false,
  );
  server.defaultResponseHeaders.removeAll('x-frame-options');

  stdout.writeln('Substitute sync server listening on $bind:$port');
  stdout.writeln('  data directory : $dataDir');
  stdout.writeln('  write token    : ${apiToken == null ? 'not required' : 'required'}');
  stdout.writeln('  content        : end-to-end encrypted, the server cannot read it');

  await for (final HttpRequest request in server) {
    // Jede Anfrage bekommt ihre eigene Fehlerbehandlung: Ein Fehler darf
    // niemals den ganzen Server mitreißen.
    unawaited(api.handle(request).catchError((Object error) {
      stderr.writeln('request failed: $error');
    }));
  }
}

/// Liest `--key value` und `--key=value`.
Map<String, String> _parseArguments(List<String> arguments) {
  final Map<String, String> options = <String, String>{};
  for (int i = 0; i < arguments.length; i++) {
    final String argument = arguments[i];
    if (!argument.startsWith('--')) continue;
    final String withoutDashes = argument.substring(2);
    final int equals = withoutDashes.indexOf('=');
    if (equals != -1) {
      options[withoutDashes.substring(0, equals)] =
          withoutDashes.substring(equals + 1);
    } else if (i + 1 < arguments.length && !arguments[i + 1].startsWith('--')) {
      options[withoutDashes] = arguments[++i];
    } else {
      options[withoutDashes] = '';
    }
  }
  return options;
}
