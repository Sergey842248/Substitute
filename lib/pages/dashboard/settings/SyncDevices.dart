import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

import '../../../models/ListPage.dart';
import '../../../models/LoadingProcess.dart';

/// Die Geräte, die in derselben Sync-Kette sind.
///
/// Die Namen kommen vom Server, sind aber **nicht** verschlüsselt: Wer die
/// Kette kennt, soll sehen können, von welchen Geräten sie befüllt wird. Die
/// eigentlichen Daten bleiben unlesbar.
class SyncDevices extends StatefulWidget {
  const SyncDevices({
    Key? key,
    required this.client,
    required this.state,
  }) : super(key: key);

  final SyncApiClient client;
  final SyncState state;

  @override
  State<SyncDevices> createState() => _SyncDevicesState();
}

class _SyncDevicesState extends State<SyncDevices> {
  List<SyncDevice>? _devices;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.client.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<SyncDevice> devices =
          await widget.client.fetchDevices(widget.state.chainId);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _error = null;
      });
    } on SyncException catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _devices = const <SyncDevice>[];
      });
    }
  }

  Future<void> _remove(SyncDevice device) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${l10n.syncLeave}: ${device.displayName}?'),
        content: Text(l10n.syncLeaveConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.syncLeave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.leaveChain(widget.state.chainId, device.deviceId);
    } on SyncException {
      // Egal – die Liste wird ohnehin neu geladen und zeigt dann den
      // tatsächlichen Stand.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<SyncDevice>? devices = _devices;

    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.syncDevices,
          onRefresh: _load,
          children: <Widget>[
            if (devices == null) const Center(child: LoadingProcess()),
            if (devices != null && devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    l10n.syncDevicesEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            for (final SyncDevice device in devices ?? const <SyncDevice>[])
              _deviceTile(l10n, device),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(AppLocalizations l10n, SyncDevice device) {
    final bool isThisDevice = device.deviceId == widget.state.deviceId;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: ListTile(
            leading: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                isThisDevice
                    ? Icons.smartphone_rounded
                    : Icons.devices_other_rounded,
              ),
            ),
            title: Text(
              isThisDevice
                  ? '${l10n.syncDeviceThisOne} · ${device.displayName}'
                  : device.displayName,
              style: const TextStyle(fontSize: 18),
            ),
            subtitle: Text(
              '${_formatTime(device.updatedAt)}'
              '${device.includesSettings ? ' · ${l10n.syncSettingsToggle}' : ''}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w100,
                color: Colors.grey,
              ),
            ),
            trailing: isThisDevice
                ? null
                : IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: l10n.syncLeave,
                    onPressed: () => _remove(device),
                  ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
