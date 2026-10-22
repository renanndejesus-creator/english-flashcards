import 'dart:convert';

import 'package:english_flashcards/services/srs.dart';
import 'package:english_flashcards/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progresso feito antes do login vai para a primeira conta', () async {
    SharedPreferences.setMockInitialValues({
      'flashcards-en-v1': jsonEncode({
        'progress': {
          'the': {'r': 1, 'i': 1, 'e': 2.5, 'd': 0, 'l': 0, 't': 1},
        },
      }),
    });
    final app = await AppState.load();

    app.useAccount('ana');
    expect(app.seenCount, 1);

    // Outra conta no mesmo navegador começa do zero.
    app.useAccount('bia');
    expect(app.seenCount, 0);
    app.grade(app.words[1], Grade.good);
    expect(app.seenCount, 1);

    // Voltando para a primeira conta, o progresso dela continua separado.
    app.useAccount('ana');
    expect(app.seenCount, 1);
    expect(app.stateOf(app.words.first), isNotNull);
    expect(app.stateOf(app.words[1]), isNull);
  });

  test(
    'resumo para o console conta palavras vistas e revisões do dia',
    () async {
      SharedPreferences.setMockInitialValues({});
      final app = await AppState.load();
      app.useAccount('ana');
      app.grade(app.words[0], Grade.good);
      app.grade(app.words[1], Grade.again);
      final s = app.summary();
      expect(s['seen'], 2);
      expect(s['reviewsToday'], 2);
      expect(s['streak'], 1);
      expect(s['lastReviewAt'], greaterThan(0));
    },
  );
}
