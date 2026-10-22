import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/study_screen.dart';
import 'screens/words_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(FlashcardsApp(state: state));
}

/// Dá acesso ao [AppState] para qualquer widget abaixo dele.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class FlashcardsApp extends StatelessWidget {
  const FlashcardsApp({super.key, required this.state});

  final AppState state;

  static const _seed = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return AppScope(
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
          home: const HomeShell(),
        ),
      ),
    );
  }
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
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
    NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Estudar'),
    NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Palavras'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
  ];

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: pages[_index],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
