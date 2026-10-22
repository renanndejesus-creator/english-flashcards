import 'dart:io';

import 'package:english_flashcards/models/word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lines = File('assets/words.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final words = [
    for (var i = 0; i < lines.length; i++) Word.parse(lines[i], i + 1),
  ];

  test('a lista tem exatamente 1500 palavras', () {
    expect(words.length, 1500);
  });

  test('não há palavras repetidas', () {
    final ids = words.map((w) => w.id).toSet();
    expect(ids.length, words.length);
  });

  test('toda palavra tem frase de exemplo traduzida', () {
    for (final w in words) {
      expect(w.exampleEnglish, isNotEmpty, reason: w.english);
      expect(w.examplePortuguese, isNotEmpty, reason: w.english);
    }
  });

  test('nomes dos arquivos de áudio são únicos', () {
    expect(words.map((w) => w.audioSlug).toSet().length, words.length);
  });

  test('toda palavra tem tradução e classe gramatical conhecida', () {
    const known = {
      'n',
      'v',
      'adj',
      'adv',
      'prep',
      'pron',
      'conj',
      'det',
      'num',
      'int',
    };
    for (final w in words) {
      expect(w.portuguese, isNotEmpty, reason: w.english);
      expect(known, contains(w.partOfSpeech), reason: w.english);
    }
  });

  test('15 níveis de 100 palavras', () {
    expect(words.first.level, 1);
    expect(words[99].level, 1);
    expect(words[100].level, 2);
    expect(words.last.level, 15);
  });
}
