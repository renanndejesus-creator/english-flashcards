import 'package:english_flashcards/models/card_state.dart';
import 'package:english_flashcards/services/srs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = 20000;

  test('palavra nova respondida "Bom" volta amanhã, depois em 3 dias', () {
    final first = Srs.schedule(null, Grade.good, today);
    expect(first.interval, 1);
    expect(first.due, today + 1);
    final second = Srs.schedule(first, Grade.good, today + 1);
    expect(second.interval, 3);
  });

  test('"Errei" zera a sequência e reduz a facilidade', () {
    final learned = Srs.schedule(Srs.schedule(null, Grade.good, today), Grade.good, today);
    final lapsed = Srs.schedule(learned, Grade.again, today);
    expect(lapsed.reps, 0);
    expect(lapsed.lapses, 1);
    expect(lapsed.due, today);
    expect(lapsed.ease, closeTo(2.3, 1e-9));
  });

  test('facilidade nunca fica abaixo do mínimo', () {
    CardState? s;
    for (var i = 0; i < 20; i++) {
      s = Srs.schedule(s, Grade.again, today);
    }
    expect(s!.ease, Srs.minEase);
  });

  test('status acompanha o intervalo', () {
    expect(Srs.status(null), WordStatus.newWord);
    expect(Srs.status(const CardState(reps: 1, interval: 1, due: today)), WordStatus.learning);
    expect(Srs.status(const CardState(reps: 3, interval: 8, due: today)), WordStatus.review);
    expect(Srs.status(const CardState(reps: 5, interval: 30, due: today)), WordStatus.mastered);
  });

  test('dateKey usa o dia local', () {
    expect(Srs.dateKey(Srs.today(DateTime(2026, 10, 22, 23, 30))), '2026-10-22');
  });
}
