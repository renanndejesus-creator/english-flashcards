import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/word.dart';
import '../services/browser.dart';
import '../services/srs.dart';
import '../state/app_state.dart';
import '../widgets/example_sentence.dart';
import '../widgets/flip_card.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.level,
    required this.onLevelChanged,
  });

  /// Nível estudado; null = todos, em ordem de frequência.
  final int? level;
  final ValueChanged<int?> onLevelChanged;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _random = Random();
  final _focusNode = FocusNode();
  List<Word>? _queue;
  bool _flipped = false;

  /// Se o cartão atual mostra o português na frente.
  bool _reversed = false;

  // Estatísticas da sessão atual.
  int _sessionTotal = 0;
  int _completed = 0;
  final Set<String> _missed = {};

  AppState get _app => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue == null) {
      _queue = _app.buildSession(level: widget.level);
      _sessionTotal = _queue!.length;
      _prepareCard();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Word? get _current => (_queue?.isEmpty ?? true) ? null : _queue!.first;

  void _prepareCard() {
    _flipped = false;
    _reversed = switch (_app.settings.direction) {
      CardDirection.enToPt => false,
      CardDirection.ptToEn => true,
      CardDirection.mixed => _random.nextBool(),
    };
    final word = _current;
    if (word != null && !_reversed && _app.settings.autoSpeak) {
      Speech.playWord(word);
    }
  }

  void _flip() {
    final word = _current;
    if (word == null) return;
    setState(() => _flipped = !_flipped);
    if (_flipped && _reversed && _app.settings.autoSpeak) Speech.playWord(word);
  }

  void _answer(Grade grade) {
    final word = _current;
    if (word == null || !_flipped) return;
    _app.grade(word, grade);
    setState(() {
      _queue!.removeAt(0);
      if (grade == Grade.again) {
        // Palavra errada volta algumas posições depois na mesma sessão.
        _missed.add(word.id);
        _queue!.insert(min(3, _queue!.length), word);
      } else {
        _completed++;
      }
      _prepareCard();
    });
  }

  void _studyMore() {
    _app.unlockExtraNew(10);
    setState(() {
      _queue = _app.buildSession(level: widget.level);
      _sessionTotal = _completed + _queue!.length;
      _prepareCard();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final word = _current;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      _flip();
    } else if (key == LogicalKeyboardKey.keyP && word != null) {
      Speech.playWord(word);
    } else if (key == LogicalKeyboardKey.keyF && word != null && _flipped) {
      Speech.playSentence(word);
    } else {
      const keys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ];
      final i = keys.indexOf(key);
      if (i == -1) return KeyEventResult.ignored;
      _answer(Grade.values[i]);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _current;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DropdownButton<int?>(
                  value: widget.level,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: widget.onLevelChanged,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos os níveis'),
                    ),
                    for (var l = 1; l <= AppState.levelCount; l++)
                      DropdownMenuItem(value: l, child: Text('Nível $l')),
                  ],
                ),
                const Spacer(),
                if (word != null)
                  Chip(
                    avatar: const Icon(Icons.layers_outlined, size: 18),
                    label: Text('${_queue!.length} na fila'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: word == null ? _buildDone(theme) : _buildCard(theme, word),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, Word word) {
    final speakButton = IconButton.filledTonal(
      tooltip: 'Ouvir pronúncia (P)',
      icon: const Icon(Icons.volume_up),
      onPressed: () => Speech.playWord(word),
    );
    final english = _CardFace(
      tag: '#${word.rank}',
      hint: 'toque para virar',
      children: [
        _title(theme, word.english),
        const SizedBox(height: 16),
        speakButton,
      ],
    );
    final portuguese = _CardFace(
      tag: word.partOfSpeechLabel,
      hint: 'toque para virar',
      children: [_title(theme, word.portuguese)],
    );
    // O verso mostra a resposta completa: palavra, tradução e frase de exemplo.
    final answer = _CardFace(
      tag: word.partOfSpeechLabel,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: _title(theme, word.english, small: true)),
            const SizedBox(width: 8),
            speakButton,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          word.portuguese,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        ExampleSentence(word: word),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FlipCard(
            flipped: _flipped,
            onTap: _flip,
            front: _reversed ? portuguese : english,
            back: answer,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 64,
          child: _flipped
              ? Row(
                  children: [
                    for (final grade in Grade.values) ...[
                      if (grade != Grade.again) const SizedBox(width: 8),
                      Expanded(
                        child: _GradeButton(
                          grade: grade,
                          interval: _app.previewInterval(word, grade),
                          onPressed: () => _answer(grade),
                        ),
                      ),
                    ],
                  ],
                )
              : FilledButton(
                  onPressed: _flip,
                  style: FilledButton.styleFrom(
                    textStyle: theme.textTheme.titleMedium,
                  ),
                  child: const Text('Mostrar resposta'),
                ),
        ),
        const SizedBox(height: 14),
        _SessionProgress(
          completed: _completed,
          total: _sessionTotal,
          missed: _missed.length,
        ),
        const SizedBox(height: 6),
        Text(
          'Atalhos: espaço vira · 1–4 responde · P palavra · F frase',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _title(ThemeData theme, String text, {bool small = false}) => Text(
    text,
    textAlign: TextAlign.center,
    style:
        (small ? theme.textTheme.headlineMedium : theme.textTheme.displaySmall)
            ?.copyWith(fontWeight: FontWeight.w800),
  );

  Widget _buildDone(ThemeData theme) {
    final hasMoreWords = _app
        .wordsInLevel(widget.level)
        .any((w) => _app.stateOf(w) == null);
    final firstTry = _completed - _missed.length;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text('Tudo em dia!', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          if (_completed > 0)
            Text(
              'Você estudou $_completed palavras e acertou ${(firstTry / _completed * 100).round()}% de primeira.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          Text(
            hasMoreWords
                ? 'Você terminou as revisões e as palavras novas de hoje.'
                : 'Você já viu todas as palavras deste nível.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (hasMoreWords)
            FilledButton.tonalIcon(
              onPressed: _studyMore,
              icon: const Icon(Icons.add),
              label: const Text('Estudar mais 10 novas'),
            ),
        ],
      ),
    );
  }
}

class _SessionProgress extends StatelessWidget {
  const _SessionProgress({
    required this.completed,
    required this.total,
    required this.missed,
  });

  final int completed;
  final int total;
  final int missed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : completed / total;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 350),
            builder: (context, v, _) =>
                LinearProgressIndicator(value: v, minHeight: 10),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('$completed de $total concluídas', style: small),
            const Spacer(),
            if (missed > 0) Text('$missed para reforçar', style: small),
            if (missed > 0) const SizedBox(width: 12),
            Text(
              '${(value * 100).round()}%',
              style: small?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.tag, required this.children, this.hint});

  final String tag;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0, constraints.maxHeight - 96),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Chip(label: Text(tag), visualDensity: VisualDensity.compact),
        ),
        if (hint != null)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Text(
              hint!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.grade,
    required this.interval,
    required this.onPressed,
  });

  final Grade grade;
  final String interval;
  final VoidCallback onPressed;

  static const _colors = {
    Grade.again: Color(0xFFDC2626),
    Grade.hard: Color(0xFFD97706),
    Grade.good: Color(0xFF16A34A),
    Grade.easy: Color(0xFF0284C7),
  };

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _colors[grade],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(interval, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
