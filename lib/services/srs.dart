import 'dart:math';

import '../models/card_state.dart';

/// Notas de resposta do usuário.
enum Grade {
  again('Errei'),
  hard('Difícil'),
  good('Bom'),
  easy('Fácil');

  const Grade(this.label);
  final String label;
}

/// Repetição espaçada baseada no algoritmo SM-2 (o mesmo princípio do Anki).
class Srs {
  static const minEase = 1.3;
  static const masteredDays = 21;

  /// Dia local atual como inteiro (dias desde 1970), para comparar vencimentos.
  static int today([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  static String dateKey(int day) => DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  ).toIso8601String().substring(0, 10);

  static CardState initial(int today) => CardState(due: today);

  /// Calcula o próximo estado da palavra a partir da nota dada.
  static CardState schedule(CardState? current, Grade grade, int today) {
    final s = current ?? initial(today);
    switch (grade) {
      case Grade.again:
        return s.copyWith(
          reps: 0,
          interval: 0,
          lapses: s.lapses + 1,
          ease: max(minEase, s.ease - 0.2),
          due: today,
        );
      case Grade.hard:
        final interval = max(1, (s.interval * 1.2).round());
        return s.copyWith(
          reps: s.reps + 1,
          interval: interval,
          ease: max(minEase, s.ease - 0.15),
          due: today + interval,
        );
      case Grade.good:
        final interval = switch (s.reps) {
          0 => 1,
          1 => 3,
          _ => (s.interval * s.ease).round(),
        };
        return s.copyWith(
          reps: s.reps + 1,
          interval: interval,
          due: today + interval,
        );
      case Grade.easy:
        final interval = s.reps == 0
            ? 4
            : (max(s.interval, 1) * s.ease * 1.3).round();
        return s.copyWith(
          reps: s.reps + 1,
          interval: interval,
          ease: s.ease + 0.15,
          due: today + interval,
        );
    }
  }

  static WordStatus status(CardState? state) {
    if (state == null) return WordStatus.newWord;
    if (state.interval >= masteredDays) return WordStatus.mastered;
    if (state.reps >= 2) return WordStatus.review;
    return WordStatus.learning;
  }

  static String formatInterval(int days) {
    if (days <= 0) return 'agora';
    if (days == 1) return '1 dia';
    if (days < 30) return '$days dias';
    final months = (days / 30).round();
    return months == 1 ? '1 mês' : '$months meses';
  }
}
