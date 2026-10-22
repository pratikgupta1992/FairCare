/// FairCare — couples version (cross-platform scaffold).
///
/// One codebase for Android + iOS. Data currently runs on the
/// local repository; Firebase plugs in behind the same interface
/// later (see firebase_repository_stub.dart / BUILD_NOTES.md).
library;

import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'app_controller.dart';
import 'babies_screen.dart';
import 'prefs_store.dart';
import 'repository.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SharedPreferencesKeyValueStore();
  final repo = LocalFairCareRepository(store);
  final controller = AppController(repo, store);
  await controller.init();
  runApp(FairCareApp(controller: controller));
}

class FairCareApp extends StatelessWidget {
  const FairCareApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'FairCare',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeShell(),
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

  static const _titles = ['Today', 'Babies', 'Analytics', 'Settings'];
  static const _screens = [
    TodayScreen(),
    BabiesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuild when app state changes (new entries, joins, defaults).
    AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('FairCare · ${_titles[_index]}')),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.child_care), label: 'Babies'),
          NavigationDestination(
              icon: Icon(Icons.balance), label: 'Analytics'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
