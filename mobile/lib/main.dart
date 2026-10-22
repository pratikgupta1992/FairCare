/// FairCare — couples version.
///
/// One codebase for Android + iOS, two backends behind the same
/// [FairCareRepository] interface:
///
/// - **Firebase mode (default):** Firebase Auth sign-in gate, then
///   the shared Firestore backend — both parents log into the same
///   babies in realtime. Needs the real config in
///   `firebase_options.dart` (see BUILD_NOTES.md); if Firebase
///   fails to initialise (e.g. config not dropped in yet), the app
///   falls back to the local backend so it still runs.
/// - **Local mode:** `--dart-define=USE_LOCAL_BACKEND=true` —
///   fully on-device mock backend, NO Firebase config needed.
///   Used by the tests and for demos before the real config lands.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'app_controller.dart';
import 'auth_screen.dart';
import 'auth_service.dart';
import 'babies_screen.dart';
import 'firebase_options.dart';
import 'firebase_repository.dart';
import 'onboarding_screen.dart';
import 'prefs_store.dart';
import 'repository.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

/// Compile-time backend switch: pass
/// `--dart-define=USE_LOCAL_BACKEND=true` to `flutter run`/`build`.
const bool kUseLocalBackend =
    bool.fromEnvironment('USE_LOCAL_BACKEND', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kUseLocalBackend) {
    await _runLocal();
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Config placeholders / missing google-services.json land
    // here on a fresh checkout. Fall back rather than crash — the
    // exact remaining setup steps are in BUILD_NOTES.md.
    debugPrint('FairCare: Firebase init failed ($e); '
        'falling back to the local backend.');
    await _runLocal();
    return;
  }
  runApp(FirebaseFairCareRoot(auth: FirebaseAuthService()));
}

Future<void> _runLocal() async {
  final store = SharedPreferencesKeyValueStore();
  final repo = LocalFairCareRepository(store);
  final controller = AppController(repo, store);
  await controller.init();
  runApp(FairCareApp(controller: controller));
}

/// Root for Firebase mode: auth gate → per-user app.
///
/// Signed out → [AuthScreen]. Signed in → builds the Firestore
/// repository + controller for that uid (loading spinner while the
/// first Firestore load completes), then hands off to the same
/// [FairCareApp] the local mode uses — including its onboarding
/// gate for users with no baby yet.
class FirebaseFairCareRoot extends StatefulWidget {
  const FirebaseFairCareRoot({super.key, required this.auth});

  final AuthService auth;

  @override
  State<FirebaseFairCareRoot> createState() => _FirebaseFairCareRootState();
}

class _FirebaseFairCareRootState extends State<FirebaseFairCareRoot> {
  String? _controllerUid;
  Future<AppController>? _controllerFuture;

  Future<AppController> _controllerFor(AuthUser user) {
    if (_controllerUid != user.uid || _controllerFuture == null) {
      _controllerUid = user.uid;
      final store = SharedPreferencesKeyValueStore();
      final repo = FirestoreFairCareRepository(uidProvider: () => user.uid);
      final controller = AppController(
        repo,
        store,
        backendLabel: 'Firebase (shared with your partner, realtime)',
        accountLabel: user.email,
        onSignOut: widget.auth.signOut,
      );
      _controllerFuture = controller.init().then((_) => controller);
    }
    return _controllerFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairCare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthUser?>(
        stream: widget.auth.userChanges,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _Splash();
          }
          final user = snap.data;
          if (user == null) {
            _controllerUid = null;
            _controllerFuture = null;
            return AuthScreen(auth: widget.auth);
          }
          return FutureBuilder<AppController>(
            future: _controllerFor(user),
            builder: (context, cs) {
              if (cs.hasError) {
                return _ErrorScreen(message: '${cs.error}');
              }
              if (!cs.hasData) return const _Splash();
              // FairCareApp builds its own MaterialApp/AppScope;
              // this root MaterialApp only hosts the gate screens.
              return FairCareApp(controller: cs.data!);
            },
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Couldn\'t load your data.\n\n$message'),
          ),
        ),
      );
}

/// The app proper, given an initialised controller. Also hosts the
/// first-run onboarding gate: a user with no baby yet lands on
/// [OnboardingScreen] and stays there until they finish it; a user
/// who already has a baby goes straight to the shell (Today).
class FairCareApp extends StatefulWidget {
  const FairCareApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<FairCareApp> createState() => _FairCareAppState();
}

class _FairCareAppState extends State<FairCareApp> {
  bool? _onboardingDone;

  @override
  Widget build(BuildContext context) {
    // Deliberately NOT listening to the controller here: the
    // decision is taken when this widget (re)builds, so creating
    // the first baby mid-onboarding doesn't yank the flow away —
    // onboarding shows its code/role steps and hands over via its
    // "Start logging care" button (setState below).
    final needsOnboarding =
        !(_onboardingDone ?? false) && widget.controller.joinedBabies.isEmpty;
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'FairCare',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: needsOnboarding
            ? _OnboardingGate(
                onFinished: () => setState(() => _onboardingDone = true))
            : const HomeShell(),
      ),
    );
  }
}

/// Keeps [FairCareApp] rebuildable while onboarding decides: the
/// onboarding screen fills in for the shell until finished. (A
/// separate widget so `HomeShell` stays the const shell used
/// everywhere else.)
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate({required this.onFinished});
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) =>
      OnboardingScreen(onFinished: onFinished);
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
