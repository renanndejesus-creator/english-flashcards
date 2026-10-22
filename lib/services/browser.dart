import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Recursos do navegador usados pelo app: voz, download e upload de arquivos.
class Browser {
  /// Pronuncia o texto em inglês com a voz do navegador.
  static void speak(String text) {
    final synth = web.window.speechSynthesis;
    synth.cancel();
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = 'en-US'
      ..rate = 0.9;
    synth.speak(utterance);
  }

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
