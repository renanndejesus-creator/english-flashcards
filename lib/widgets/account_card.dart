import 'package:flutter/material.dart';

import '../main.dart';
import '../services/cloud_sync.dart';

/// Login com Google e situação da sincronização com a nuvem.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, this.compact = false});

  /// Versão curta para a tela inicial: só aparece se o usuário não entrou.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!sync.available) {
      if (compact) return const SizedBox.shrink();
      return const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Sincronização na nuvem indisponível'),
        subtitle: Text('O progresso está salvo só neste navegador.'),
      );
    }

    final user = sync.user;
    if (user == null) {
      return Card.filled(
        color: scheme.primaryContainer,
        margin: compact
            ? const EdgeInsets.only(top: 16)
            : const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Salve seu progresso na nuvem',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Hoje ele está só neste navegador. Entre com sua conta Google para não '
                'perder nada e continuar em qualquer aparelho.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (sync.status == SyncStatus.error && sync.error != null) ...[
                const SizedBox(height: 8),
                Text(sync.error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: sync.signIn,
                icon: const Icon(Icons.login),
                label: const Text('Entrar com Google'),
              ),
            ],
          ),
        ),
      );
    }

    if (compact) return const SizedBox.shrink();

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
