import 'package:english_flashcards/services/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> snap({
  int updatedAt = 0,
  int resetAt = 0,
  Map<String, dynamic> progress = const {},
  Map<String, dynamic> days = const {},
  Map<String, dynamic>? settings,
}) => {
  'updatedAt': updatedAt,
  'resetAt': resetAt,
  'progress': progress,
  'days': days,
  'settings': settings,
};

Map<String, dynamic> card(int t, {int reps = 1}) => {
  'r': reps,
  'i': 1,
  'e': 2.5,
  'd': 1,
  'l': 0,
  't': t,
};

void main() {
  test('cada palavra fica com a revisão mais recente', () {
    final local = snap(
      progress: {'the': card(100, reps: 1), 'be': card(300, reps: 5)},
    );
    final remote = snap(progress: {'the': card(200, reps: 2), 'and': card(50)});
    final merged = mergeSnapshots(local, remote)['progress'] as Map;
    expect(merged['the']['r'], 2);
    expect(merged['be']['r'], 5);
    expect(merged.keys, containsAll(['the', 'be', 'and']));
  });

  test('estatísticas diárias ficam com o maior valor', () {
    final local = snap(
      days: {
        '2026-10-22': {'reviews': 10, 'learned': 3},
      },
    );
    final remote = snap(
      days: {
        '2026-10-22': {'reviews': 4, 'learned': 5},
        '2026-10-21': {'reviews': 2},
      },
    );
    final days = mergeSnapshots(local, remote)['days'] as Map;
    expect(days['2026-10-22'], {'reviews': 10, 'learned': 5});
    expect(days['2026-10-21']['reviews'], 2);
  });

  test('ajustes vêm do lado alterado por último', () {
    final local = snap(updatedAt: 10, settings: {'newPerDay': 20});
    final remote = snap(updatedAt: 20, settings: {'newPerDay': 50});
    expect(mergeSnapshots(local, remote)['settings'], {'newPerDay': 50});
  });

  test('apagar progresso descarta revisões anteriores em outros aparelhos', () {
    final local = snap(resetAt: 1000);
    final remote = snap(progress: {'old': card(500), 'new': card(1500)});
    final merged = mergeSnapshots(local, remote);
    expect((merged['progress'] as Map).keys, ['new']);
    expect(merged['resetAt'], 1000);
  });

  test('mesclar é idempotente', () {
    final local = snap(
      updatedAt: 5,
      progress: {'the': card(100)},
      days: {
        '2026-10-22': {'reviews': 1},
      },
    );
    final remote = snap(updatedAt: 7, progress: {'be': card(200)});
    final once = mergeSnapshots(local, remote);
    expect(mergeSnapshots(once, remote), once);
    expect(mergeSnapshots(once, once), once);
  });
}
