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

/// Estado global do app: vocabulário, progresso e ajustes, salvos no navegador.
class AppState extends ChangeNotifier {
  AppState._(this._prefs, this.words);

  static const _storageKey = 'flashcards-en-v1';
  static const levelCount = 15;

  final SharedPreferences _prefs;
  final List<Word> words;

  Map<String, CardState> _progress = {};
  Map<String, DayStats> _days = {};
  Settings _settings = const Settings();

  Settings get settings => _settings;

  static Future<AppState> load() async {
    final raw = await rootBundle.loadString('assets/words.txt');
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final words = [
      for (var i = 0; i < lines.length; i++) Word.parse(lines[i], i + 1),
    ];
    final state = AppState._(await SharedPreferences.getInstance(), words);
    final saved = state._prefs.getString(_storageKey);
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

  Map<String, dynamic> _toJson() => {
    'version': 1,
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
  }

  void _save() {
    _prefs.setString(_storageKey, jsonEncode(_toJson()));
    notifyListeners();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(_toJson());

  /// Substitui o progresso pelo conteúdo de um backup. Lança erro se for inválido.
  void importJson(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['progress'] is! Map) {
      throw const FormatException('Arquivo de progresso inválido.');
    }
    _restore(json);
    _save();
  }

  void resetProgress() {
    _progress = {};
    _days = {};
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
    _progress[word.id] = Srs.schedule(previous, grade, today);
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
