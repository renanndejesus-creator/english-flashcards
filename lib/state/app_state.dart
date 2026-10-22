import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_state.dart';
import '../models/word.dart';
import '../services/srs.dart';

enum CardDirection {
  enToPt('Inglês → Português'),
  ptToEn('Português → Inglês'),
  mixed('Misturado');

  const CardDirection(this.label);
  final String label;
}

class Settings {
  const Settings({
    this.newPerDay = 20,
    this.direction = CardDirection.enToPt,
    this.autoSpeak = false,
    this.themeMode = ThemeMode.system,
  });

  final int newPerDay;
  final CardDirection direction;
  final bool autoSpeak;
  final ThemeMode themeMode;

  Settings copyWith({
    int? newPerDay,
    CardDirection? direction,
    bool? autoSpeak,
    ThemeMode? themeMode,
  }) {
    return Settings(
      newPerDay: newPerDay ?? this.newPerDay,
      direction: direction ?? this.direction,
      autoSpeak: autoSpeak ?? this.autoSpeak,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'newPerDay': newPerDay,
    'direction': direction.name,
    'autoSpeak': autoSpeak,
    'themeMode': themeMode.name,
  };

  factory Settings.fromJson(Map<String, dynamic> json) {
    const d = Settings();
    return Settings(
      newPerDay: (json['newPerDay'] as num?)?.toInt() ?? d.newPerDay,
      direction:
          CardDirection.values.asNameMap()[json['direction']] ?? d.direction,
      autoSpeak: json['autoSpeak'] as bool? ?? d.autoSpeak,
      themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? d.themeMode,
    );
  }
}

/// Atividade de um dia: revisões feitas e palavras novas introduzidas.
class DayStats {
  DayStats({this.reviews = 0, this.learned = 0, this.extraNew = 0});

  int reviews;
  int learned;

  /// Palavras novas extras liberadas pelo botão "estudar mais".
  int extraNew;

  Map<String, dynamic> toJson() => {
    'reviews': reviews,
    'learned': learned,
    'extraNew': extraNew,
  };

  factory DayStats.fromJson(Map<String, dynamic> json) => DayStats(
    reviews: (json['reviews'] as num?)?.toInt() ?? 0,
    learned: (json['learned'] as num?)?.toInt() ?? 0,
    extraNew: (json['extraNew'] as num?)?.toInt() ?? 0,
  );
}

/// Estado global do app: vocabulário, progresso e ajustes, salvos no navegador
/// (e na nuvem pelo CloudSync, quando o usuário entra com Google).
class AppState extends ChangeNotifier {
  AppState._(this._prefs, this.words);

  /// Chave do progresso salvo antes do login (passa para a primeira conta).
  static const _legacyKey = 'flashcards-en-v1';
  static const levelCount = 15;

  /// Cada conta tem seu próprio progresso neste navegador.
  String _storageKey = _legacyKey;

  final SharedPreferences _prefs;
  final List<Word> words;

  Map<String, CardState> _progress = {};
  Map<String, DayStats> _days = {};
  Settings _settings = const Settings();

  /// Última alteração local (ms) e último "apagar progresso" (ms).
  int _updatedAt = 0;
  int _resetAt = 0;

  final _changes = StreamController<void>.broadcast();

  /// Emite a cada alteração feita pelo usuário neste navegador.
  Stream<void> get changes => _changes.stream;

  Settings get settings => _settings;

  static Future<AppState> load() async {
    final raw = await rootBundle.loadString('assets/words.txt');
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final words = [
      for (var i = 0; i < lines.length; i++) Word.parse(lines[i], i + 1),
    ];
    final state = AppState._(await SharedPreferences.getInstance(), words);
    final saved = state._prefs.getString(state._storageKey);
    if (saved != null) {
      try {
        state._restore(jsonDecode(saved) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Progresso salvo inválido, começando do zero: $e');
      }
    }
    return state;
  }

  // ---------- Persistência ----------

  /// Troca para o progresso local da conta [uid] (null = sem conta).
  void useAccount(String? uid) {
    final key = uid == null ? _legacyKey : '$_legacyKey-$uid';
    if (key == _storageKey) return;
    _storageKey = key;
    var saved = _prefs.getString(key);
    if (saved == null && uid != null) {
      // Progresso feito antes do login vai para a primeira conta que entrar.
      saved = _prefs.getString(_legacyKey);
      if (saved != null) {
        _prefs.setString(key, saved);
        _prefs.remove(_legacyKey);
      }
    }
    _progress = {};
    _days = {};
    _settings = const Settings();
    _updatedAt = 0;
    _resetAt = 0;
    if (saved != null) {
      try {
        _restore(jsonDecode(saved) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Progresso salvo inválido, começando do zero: $e');
      }
    }
    notifyListeners();
  }

  /// Resumo do progresso, gravado na nuvem para o console de administração.
  Map<String, dynamic> summary() {
    final lastReview = _progress.values.fold<int>(
      0,
      (m, c) => c.reviewedAt > m ? c.reviewedAt : m,
    );
    return {
      'seen': seenCount,
      'mastered': countWithStatus(WordStatus.mastered),
      'due': dueWords().length,
      'streak': streak,
      'reviewsToday': _days[Srs.dateKey(today)]?.reviews ?? 0,
      'lastReviewAt': lastReview,
    };
  }

  /// Snapshot completo do progresso, no formato salvo localmente e na nuvem.
  Map<String, dynamic> snapshot() => {
    'version': 1,
    'updatedAt': _updatedAt,
    'resetAt': _resetAt,
    'progress': _progress.map((k, v) => MapEntry(k, v.toJson())),
    'days': _days.map((k, v) => MapEntry(k, v.toJson())),
    'settings': _settings.toJson(),
  };

  void _restore(Map<String, dynamic> json) {
    final progress = (json['progress'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, CardState.fromJson(v as Map<String, dynamic>)),
    );
    final days = (json['days'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, DayStats.fromJson(v as Map<String, dynamic>)),
    );
    final settings = Settings.fromJson(
      json['settings'] as Map<String, dynamic>? ?? {},
    );
    _progress = progress;
    _days = days;
    _settings = settings;
    _updatedAt = (json['updatedAt'] as num?)?.toInt() ?? 0;
    _resetAt = (json['resetAt'] as num?)?.toInt() ?? 0;
  }

  /// Salva no navegador. [local] = alteração feita aqui (avisa o CloudSync).
  void _save({bool local = true}) {
    if (local) _updatedAt = DateTime.now().millisecondsSinceEpoch;
    _prefs.setString(_storageKey, jsonEncode(snapshot()));
    notifyListeners();
    if (local) _changes.add(null);
  }

  /// Aplica um snapshot vindo da nuvem (já mesclado com o local).
  void applySnapshot(Map<String, dynamic> json) {
    _restore(json);
    _save(local: false);
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(snapshot());

  /// Substitui o progresso pelo conteúdo de um backup. Lança erro se for inválido.
  void importJson(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['progress'] is! Map) {
      throw const FormatException('Arquivo de progresso inválido.');
    }
    _restore(json);
    // O backup importado substitui o progresso, inclusive na nuvem.
    final now = DateTime.now().millisecondsSinceEpoch;
    _resetAt = now - 1;
    _progress = _progress.map(
      (k, v) => MapEntry(k, v.copyWith(reviewedAt: now)),
    );
    _save();
  }

  void resetProgress() {
    _progress = {};
    _days = {};
    _resetAt = DateTime.now().millisecondsSinceEpoch;
    _save();
  }

  void updateSettings(Settings settings) {
    _settings = settings;
    _save();
  }

  // ---------- Consultas ----------

  int get today => Srs.today();

  DayStats get _todayStats =>
      _days.putIfAbsent(Srs.dateKey(today), DayStats.new);

  CardState? stateOf(Word word) => _progress[word.id];

  WordStatus statusOf(Word word) => Srs.status(_progress[word.id]);

  Iterable<Word> wordsInLevel(int? level) =>
      level == null ? words : words.where((w) => w.level == level);

  List<Word> dueWords({int? level}) {
    final t = today;
    final due =
        wordsInLevel(level).where((w) {
          final s = _progress[w.id];
          return s != null && s.due <= t;
        }).toList()..sort(
          (a, b) => _progress[a.id]!.due.compareTo(_progress[b.id]!.due),
        );
    return due;
  }

  int get newRemainingToday {
    final stats = _days[Srs.dateKey(today)];
    final allowed = _settings.newPerDay + (stats?.extraNew ?? 0);
    return (allowed - (stats?.learned ?? 0)).clamp(0, words.length);
  }

  List<Word> newWords({int? level, int? limit}) {
    final unseen = wordsInLevel(level)
        .where((w) => !_progress.containsKey(w.id));
    return unseen.take(limit ?? newRemainingToday).toList();
  }

  /// Fila de estudo: revisões vencidas primeiro, depois palavras novas.
  List<Word> buildSession({int? level}) => [
    ...dueWords(level: level),
    ...newWords(level: level),
  ];

  int get seenCount => _progress.length;

  int countWithStatus(WordStatus status) =>
      words.where((w) => statusOf(w) == status).length;

  /// Fração de palavras do nível já vistas (0 a 1).
  double levelProgress(int level) {
    final inLevel = wordsInLevel(level).toList();
    if (inLevel.isEmpty) return 0;
    return inLevel.where((w) => _progress.containsKey(w.id)).length /
        inLevel.length;
  }

  /// Dias seguidos com pelo menos uma revisão, contando até hoje (ou ontem).
  int get streak {
    var day = today;
    if ((_days[Srs.dateKey(day)]?.reviews ?? 0) == 0) day--;
    var count = 0;
    while ((_days[Srs.dateKey(day)]?.reviews ?? 0) > 0) {
      count++;
      day--;
    }
    return count;
  }

  // ---------- Ações ----------

  void grade(Word word, Grade grade) {
    final previous = _progress[word.id];
    final stats = _todayStats;
    if (previous == null) stats.learned++;
    stats.reviews++;
    _progress[word.id] = Srs.schedule(
      previous,
      grade,
      today,
    ).copyWith(reviewedAt: DateTime.now().millisecondsSinceEpoch);
    _save();
  }

  /// Próximo intervalo previsto para cada nota (mostrado nos botões).
  String previewInterval(Word word, Grade grade) => Srs.formatInterval(
    Srs.schedule(_progress[word.id], grade, today).interval,
  );

  void unlockExtraNew(int amount) {
    _todayStats.extraNew += amount;
    _save();
  }
}
