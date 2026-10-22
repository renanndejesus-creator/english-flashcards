import 'package:flutter/material.dart';

import '../main.dart';
import '../services/browser.dart';
import '../services/srs.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settings = app.settings;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _header(theme, 'Estudo'),
        ListTile(
          title: const Text('Novas palavras por dia'),
          subtitle: Slider(
            value: settings.newPerDay.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            label: '${settings.newPerDay}',
            onChanged: (v) => app.updateSettings(settings.copyWith(newPerDay: v.round())),
          ),
          trailing: Text('${settings.newPerDay}', style: theme.textTheme.titleMedium),
        ),
        ListTile(
          title: const Text('Direção dos cartões'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<CardDirection>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CardDirection.enToPt, label: Text('EN → PT')),
                ButtonSegment(value: CardDirection.ptToEn, label: Text('PT → EN')),
                ButtonSegment(value: CardDirection.mixed, label: Text('Misto')),
              ],
              selected: {settings.direction},
              onSelectionChanged: (s) => app.updateSettings(settings.copyWith(direction: s.first)),
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Pronunciar automaticamente'),
          subtitle: const Text('Fala a palavra em inglês quando ela aparece'),
          value: settings.autoSpeak,
          onChanged: (v) => app.updateSettings(settings.copyWith(autoSpeak: v)),
        ),
        _header(theme, 'Aparência'),
        ListTile(
          title: const Text('Tema'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Automático')),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => app.updateSettings(settings.copyWith(themeMode: s.first)),
            ),
          ),
        ),
        _header(theme, 'Seu progresso'),
        const ListTile(
          dense: true,
          subtitle: Text(
            'O progresso fica salvo neste navegador. Exporte um backup para não perder '
            'ou para continuar em outro aparelho.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Exportar progresso'),
          onTap: () {
            Browser.download('flashcards-progresso-${Srs.dateKey(app.today)}.json', app.exportJson());
          },
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Importar progresso'),
          onTap: () => _import(context, app),
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          title: Text('Apagar progresso', style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => _confirmReset(context, app),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      );

  Future<void> _import(BuildContext context, AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await Browser.pickTextFile();
    if (text == null) return;
    try {
      app.importJson(text);
      messenger.showSnackBar(const SnackBar(content: Text('Progresso importado!')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Arquivo inválido.')));
    }
  }

  Future<void> _confirmReset(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar progresso?'),
        content: const Text('Todo o histórico de estudo deste navegador será apagado. Isso não pode ser desfeito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) app.resetProgress();
  }
}
