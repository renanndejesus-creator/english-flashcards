import 'package:flutter/material.dart';

import '../main.dart';
import '../services/cloud_sync.dart';

/// Conta Google conectada e situação da sincronização com a nuvem.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final user = sync.user;
    if (user == null) return const SizedBox.shrink();

    final photo = user.photoURL;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: photo == null ? null : NetworkImage(photo),
        child: photo == null
            ? Text((user.displayName ?? user.email ?? '?')[0].toUpperCase())
            : null,
      ),
      title: Text(user.displayName ?? user.email ?? 'Conta Google'),
      subtitle: Row(
        children: [
          Icon(
            _statusIcon(sync.status),
            size: 16,
            color: sync.status == SyncStatus.error ? scheme.error : null,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(_statusText(context, sync))),
        ],
      ),
      trailing: TextButton(onPressed: sync.signOut, child: const Text('Sair')),
    );
  }

  static IconData _statusIcon(SyncStatus status) => switch (status) {
    SyncStatus.syncing => Icons.cloud_sync_outlined,
    SyncStatus.error => Icons.error_outline,
    _ => Icons.cloud_done_outlined,
  };

  static String _statusText(BuildContext context, CloudSync sync) {
    switch (sync.status) {
      case SyncStatus.syncing:
        return 'Sincronizando…';
      case SyncStatus.error:
        return sync.error ?? 'Erro ao sincronizar';
      default:
        final last = sync.lastSync;
        if (last == null) return 'Salvo na nuvem';
        final time = TimeOfDay.fromDateTime(last).format(context);
        return 'Salvo na nuvem às $time';
    }
  }
}
