import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/browser.dart';

/// Frase de exemplo com a palavra destacada, botão de áudio e tradução.
class ExampleSentence extends StatelessWidget {
  const ExampleSentence({super.key, required this.word, this.center = false});

  final Word word;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.titleMedium?.copyWith(height: 1.4);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: center
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: _highlight(word, base, scheme.primary)),
                  textAlign: center ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 4),
                Text(
                  word.examplePortuguese,
                  textAlign: center ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ouvir frase (F)',
            icon: const Icon(Icons.record_voice_over_outlined),
            onPressed: () => Speech.playSentence(word),
          ),
        ],
      ),
    );
  }

  /// Destaca a palavra estudada na frase, incluindo flexões regulares
  /// ("studies", "moved"); formas irregulares ("went") ficam sem destaque.
  static List<TextSpan> _highlight(Word word, TextStyle? base, Color color) {
    final sentence = word.exampleEnglish;
    final stem = word.id.length > 3 && word.id.endsWith('e')
        ? word.id.substring(0, word.id.length - 1)
        : word.id;
    final match = RegExp(
      '\\b${RegExp.escape(stem)}[a-z\']*',
      caseSensitive: false,
    ).firstMatch(sentence);
    if (match == null) return [TextSpan(text: sentence, style: base)];
    return [
      TextSpan(text: sentence.substring(0, match.start), style: base),
      TextSpan(
        text: match.group(0),
        style: base?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
      TextSpan(text: sentence.substring(match.end), style: base),
    ];
  }
}
