import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/word.dart';

/// Áudio das palavras e frases.
///
/// Toca as gravações com voz neural de `web/audio/` (geradas por
/// tool/generate_audio.py). Se o arquivo não carregar, usa a melhor voz
/// em inglês disponível no navegador.
class Speech {
  static web.HTMLAudioElement? _player;

  static void playWord(Word word) =>
      _play('audio/words/${word.audioSlug}.mp3', word.english);

  static void playSentence(Word word) =>
      _play('audio/sentences/${word.audioSlug}.mp3', word.exampleEnglish);

  static void _play(String url, String fallbackText) {
    _player?.pause();
    web.window.speechSynthesis.cancel();
    final player = web.HTMLAudioElement()..src = url;
    _player = player;
    player.play().toDart.then(
      (_) {},
      onError: (Object _) {
        if (identical(_player, player)) _speakWithBrowser(fallbackText);
      },
    );
  }

  /// Nomes de vozes mais naturais, em ordem de preferência.
  static const _preferredVoices = [
    'natural',
    'neural',
    'google us english',
    'samantha',
    'aria',
    'jenny',
    'ava',
    'zira',
  ];

  static void _speakWithBrowser(String text) {
    final synth = web.window.speechSynthesis;
    final voices = synth
        .getVoices()
        .toDart
        .where((v) => v.lang.startsWith('en'))
        .toList();
    web.SpeechSynthesisVoice? best;
    for (final name in _preferredVoices) {
      for (final v in voices) {
        if (v.name.toLowerCase().contains(name)) {
          best = v;
          break;
        }
      }
      if (best != null) break;
    }
    best ??=
        voices.where((v) => v.lang == 'en-US').firstOrNull ??
        voices.firstOrNull;
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = 'en-US'
      ..rate = 0.9;
    if (best != null) utterance.voice = best;
    synth.speak(utterance);
  }
}

/// Download e upload de arquivos pelo navegador.
class Browser {
  /// Baixa um arquivo de texto gerado pelo app.
  static void download(String fileName, String content) {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  /// Abre o seletor de arquivos e devolve o conteúdo do arquivo escolhido.
  static Future<String?> pickTextFile() {
    final completer = Completer<String?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'application/json,.json';
    input.onchange = (web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      file.text().toDart.then(
        (text) => completer.complete(text.toDart),
        onError: (Object _) => completer.complete(null),
      );
    }.toJS;
    input.click();
    return completer.future;
  }
}
