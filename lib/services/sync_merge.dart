import 'dart:math';

import 'srs.dart';

/// Mescla dois snapshots de progresso (o deste navegador e o da nuvem).
///
/// Regras:
/// - Cada palavra fica com o estado revisado mais recentemente (`t`).
/// - Estatísticas diárias ficam com o maior valor de cada campo.
/// - Ajustes vêm do snapshot alterado mais recentemente (`updatedAt`).
/// - "Apagar progresso" (`resetAt`) descarta o que foi estudado antes dele,
///   inclusive em outros aparelhos.
Map<String, dynamic> mergeSnapshots(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final resetAt = max(_int(local['resetAt']), _int(remote['resetAt']));
  final resetDay = resetAt == 0
      ? null
      : Srs.dateKey(Srs.today(DateTime.fromMillisecondsSinceEpoch(resetAt)));

  final progress = <String, dynamic>{};
  for (final source in [remote, local]) {
    final cards = source['progress'] as Map<String, dynamic>? ?? {};
    cards.forEach((word, value) {
      final card = value as Map<String, dynamic>;
      final t = _int(card['t']);
      if (resetAt > 0 && t <= resetAt) return;
      final current = progress[word] as Map<String, dynamic>?;
      // Em empate, vale o local (segunda iteração).
      if (current == null || t >= _int(current['t'])) progress[word] = card;
    });
  }

  final days = <String, dynamic>{};
  for (final source in [remote, local]) {
    final entries = source['days'] as Map<String, dynamic>? ?? {};
    entries.forEach((day, value) {
      if (resetDay != null && day.compareTo(resetDay) < 0) return;
      final stats = value as Map<String, dynamic>;
      final current = days[day] as Map<String, dynamic>? ?? {};
      days[day] = {
        for (final key in {...current.keys, ...stats.keys})
          key: max(_int(current[key]), _int(stats[key])),
      };
    });
  }

  final localNewer = _int(local['updatedAt']) >= _int(remote['updatedAt']);
  final newer = localNewer ? local : remote;

  return {
    'version': 1,
    'updatedAt': max(_int(local['updatedAt']), _int(remote['updatedAt'])),
    'resetAt': resetAt,
    'progress': progress,
    'days': days,
    'settings': newer['settings'] ?? local['settings'] ?? remote['settings'],
  };
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
