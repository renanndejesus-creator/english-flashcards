/// Estado de repetição espaçada de uma palavra.
class CardState {
  const CardState({
    this.reps = 0,
    this.interval = 0,
    this.ease = 2.5,
    required this.due,
    this.lapses = 0,
  });

  /// Acertos seguidos.
  final int reps;

  /// Dias até a próxima revisão.
  final int interval;

  /// Fator de facilidade (SM-2).
  final double ease;

  /// Dia (dias desde 1970, no fuso local) em que a palavra volta para revisão.
  final int due;

  /// Quantas vezes a palavra foi esquecida.
  final int lapses;

  CardState copyWith({int? reps, int? interval, double? ease, int? due, int? lapses}) {
    return CardState(
      reps: reps ?? this.reps,
      interval: interval ?? this.interval,
      ease: ease ?? this.ease,
      due: due ?? this.due,
      lapses: lapses ?? this.lapses,
    );
  }

  Map<String, dynamic> toJson() =>
      {'r': reps, 'i': interval, 'e': ease, 'd': due, 'l': lapses};

  factory CardState.fromJson(Map<String, dynamic> json) => CardState(
        reps: (json['r'] as num?)?.toInt() ?? 0,
        interval: (json['i'] as num?)?.toInt() ?? 0,
        ease: (json['e'] as num?)?.toDouble() ?? 2.5,
        due: (json['d'] as num).toInt(),
        lapses: (json['l'] as num?)?.toInt() ?? 0,
      );
}

enum WordStatus {
  newWord('Nova'),
  learning('Aprendendo'),
  review('Revisando'),
  mastered('Dominada');

  const WordStatus(this.label);
  final String label;
}
