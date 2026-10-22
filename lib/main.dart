import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/study_screen.dart';
import 'screens/words_screen.dart';
import 'services/browser.dart';
import 'services/cloud_sync.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Browser.requestPersistentStorage();
  final state = await AppState.load();
  final sync = CloudSync(state);
  await sync.init();
  runApp(FlashcardsApp(state: state, sync: sync));
}

/// Dá acesso ao [AppState] para qualquer widget abaixo dele.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Dá acesso ao [CloudSync] (login e sincronização com a nuvem).
class SyncScope extends InheritedNotifier<CloudSync> {
  const SyncScope({super.key, required CloudSync sync, required super.child})
    : super(notifier: sync);

  static CloudSync of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()!.notifier!;
}

class FlashcardsApp extends StatelessWidget {
  const FlashcardsApp({super.key, required this.state, required this.sync});

  final AppState state;
  final CloudSync sync;

  static const _seed = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return SyncScope(
      sync: sync,
      child: AppScope(
        state: state,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => MaterialApp(
            title: 'Flashcards de Inglês',
            debugShowCheckedModeBanner: false,
            themeMode: state.settings.themeMode,
            theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
            darkTheme: ThemeData(
              colorSchemeSeed: _seed,
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            home: const AuthGate(),
          ),
        ),
      ),
    );
  }
}

/// O login com Google é obrigatório: sem usuário, só a tela de login aparece.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    return sync.user != null ? const HomeShell() : const LoginScreen();
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int? _studyLevel;

  /// Muda para a aba Estudar com o nível escolhido (null = todos).
  void _startStudy(int? level) => setState(() {
    _studyLevel = level;
    _index = 1;
  });

  static const _destinations = [
    _Destination('Início', Icons.home_outlined, Icons.home),
    _Destination('Estudar', Icons.style_outlined, Icons.style),
    _Destination('Palavras', Icons.list_alt_outlined, Icons.list_alt),
    _Destination('Ajustes', Icons.settings_outlined, Icons.settings),
  ];

  /// Abaixo desta largura o menu vira uma gaveta lateral esquerda.
  static const _railBreakpoint = 640.0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onStudy: _startStudy),
      StudyScreen(
        key: ValueKey('study-$_studyLevel'),
        level: _studyLevel,
        onLevelChanged: (level) => setState(() => _studyLevel = level),
      ),
      const WordsScreen(),
      const SettingsScreen(),
    ];
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: pages[_index],
        ),
      ),
    );
    final width = MediaQuery.sizeOf(context).width;

    if (width < _railBreakpoint) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_destinations[_index].label),
          centerTitle: false,
        ),
        drawer: NavigationDrawer(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            Navigator.pop(context);
          },
          children: [
            const _Brand(padding: EdgeInsets.fromLTRB(28, 24, 16, 16)),
            for (final d in _destinations)
              NavigationDrawerDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
              ),
          ],
        ),
        body: content,
      );
    }

    final extended = width >= 1100;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: extended
                  ? const _Brand()
                  : const Text('🃏', style: TextStyle(fontSize: 28)),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🃏', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Text(
            'Flashcards EN',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
