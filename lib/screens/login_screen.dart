import 'package:flutter/material.dart';

import '../main.dart';

/// Tela de entrada: login com Google antes de abrir o app.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onContinueAsGuest});

  /// Abre o app sem conta (progresso só neste navegador).
  final VoidCallback onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text('🃏', style: TextStyle(fontSize: 44)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Flashcards de Inglês',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aprenda as 1500 palavras mais usadas do inglês com repetição espaçada.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _Feature(
                        icon: Icons.cloud_done_outlined,
                        text: 'Progresso salvo na nuvem',
                      ),
                      const _Feature(
                        icon: Icons.devices_outlined,
                        text: 'Continue em qualquer aparelho',
                      ),
                      const _Feature(
                        icon: Icons.record_voice_over_outlined,
                        text: 'Áudio natural e frases de exemplo',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: sync.signingIn ? null : sync.signIn,
                          icon: sync.signingIn
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            sync.signingIn
                                ? 'Aguardando o Google…'
                                : 'Entrar com Google',
                          ),
                          style: FilledButton.styleFrom(
                            textStyle: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                      if (sync.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          sync.error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onContinueAsGuest,
                        child: const Text('Continuar sem entrar'),
                      ),
                      Text(
                        'Sem entrar, o progresso fica salvo só neste navegador.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
