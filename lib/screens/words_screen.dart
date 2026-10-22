import 'package:flutter/material.dart';

import '../main.dart';
import '../models/card_state.dart';
import '../services/browser.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  String _query = '';
  WordStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final words = app.words.where((w) {
      if (_filter != null && app.statusOf(w) != _filter) return false;
      if (query.isEmpty) return true;
      return w.english.toLowerCase().contains(query) || w.portuguese.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            hintText: 'Buscar em inglês ou português…',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final status in [null, ...WordStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status?.label ?? 'Todas'),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('${words.length} palavras', style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: words.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final w = words[i];
              final status = app.statusOf(w);
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Text('#${w.rank}', style: theme.textTheme.bodySmall),
                ),
                title: Text(w.english, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${w.portuguese} · ${w.partOfSpeechLabel}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusBadge(status: status),
                    IconButton(
                      tooltip: 'Ouvir',
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () => Browser.speak(w.english),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final WordStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      WordStatus.newWord => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      WordStatus.learning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      WordStatus.review => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      WordStatus.mastered => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
