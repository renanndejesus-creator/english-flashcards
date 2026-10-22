import 'package:flutter/material.dart';

import '../main.dart';
import '../models/card_state.dart';
import '../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onStudy});

  /// Abre o estudo; null = todos os níveis.
  final ValueChanged<int?> onStudy;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final name = SyncScope.of(context).firstName;
    final theme = Theme.of(context);
    final seen = app.seenCount;
    final total = app.words.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          name == null ? 'Olá! 👋' : 'Olá $name! 👋',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'As $total palavras mais usadas do inglês, com repetição espaçada.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // 2 colunas no celular, até 5 em telas largas, todas com a mesma largura.
            final columns = (constraints.maxWidth / 140).floor().clamp(2, 5);
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            final stats = [
              _StatCard(
                value: app.dueWords().length,
                label: 'para revisar hoje',
                icon: Icons.replay,
              ),
              _StatCard(
                value: app.newWords().length,
                label: 'novas hoje',
                icon: Icons.fiber_new_outlined,
              ),
              _StatCard(
                value: seen,
                label: 'palavras vistas',
                icon: Icons.visibility_outlined,
              ),
              _StatCard(
                value: app.countWithStatus(WordStatus.mastered),
                label: 'dominadas',
                icon: Icons.emoji_events_outlined,
              ),
              _StatCard(
                value: app.streak,
                label: 'dias seguidos',
                icon: Icons.local_fire_department_outlined,
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in stats) SizedBox(width: width, child: s),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Progresso total', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              '${(seen / total * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: seen / total, minHeight: 10),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => onStudy(null),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Começar estudo'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 28),
        Text('Níveis', style: theme.textTheme.titleLarge),
        Text(
          'Cada nível tem 100 palavras, em ordem de frequência.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisExtent: 92,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: AppState.levelCount,
          itemBuilder: (context, i) => _LevelCard(
            level: i + 1,
            progress: app.levelProgress(i + 1),
            onTap: () => onStudy(i + 1),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.progress,
    required this.onTap,
  });

  final int level;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = (level - 1) * 100 + 1;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nível $level',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'palavras $first–${first + 99}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
