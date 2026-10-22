// Tests for the Firebase-mode shell pieces that do NOT need a
// real Firebase project:
//  - the auth gate shows the sign-in screen while signed out
//    (with a fake AuthService — Firebase itself is never touched);
//  - connect-code normalization (the pure part of join-by-code);
//  - first-run onboarding in LOCAL mode end to end: a user with
//    no baby creates one, sees its connect code big, picks a
//    default role, and lands on Today.
//
// The Firestore repository's join path itself is deliberately not
// faked here — it needs a real project config to test honestly.
import 'dart:async';

import 'package:faircare/app_controller.dart';
import 'package:faircare/auth_service.dart';
import 'package:faircare/main.dart';
import 'package:faircare/models.dart';
import 'package:faircare/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthService implements AuthService {
  FakeAuthService([this._user]);
  AuthUser? _user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get userChanges async* {
    yield _user;
    yield* _ctrl.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}

void main() {
  test('connect codes normalize to trimmed uppercase', () {
    expect(normalizeConnectCode(' k7qx2m '), 'K7QX2M');
    expect(normalizeConnectCode('K7QX2M'), 'K7QX2M');
    expect(normalizeConnectCode(''), '');
  });

  testWidgets('auth gate shows the sign-in screen when signed out',
      (tester) async {
    await tester.pumpWidget(FirebaseFairCareRoot(auth: FakeAuthService()));
    await tester.pumpAndSettle();

    // Sign-in form is shown; the app shell is not.
    expect(find.text('Sign in'), findsWidgets);
    expect(
        find.text(
            'Welcome back — sign in to see your shared care log.'),
        findsOneWidget);
    expect(find.text('FairCare · Today'), findsNothing);

    // Toggle to sign-up keeps us on the gate with the other form.
    await tester.tap(find.text('New to FairCare? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('onboarding: create a baby, see its code, pick a role, start',
      (tester) async {
    final repo = LocalFairCareRepository.memory();
    await repo.init();
    final controller = AppController(repo, MemoryKeyValueStore());
    await controller.init();
    // Remove the seeded baby so this user has none — the state a
    // brand-new signed-in user is in.
    await repo.deleteBaby(repo.babies.first.id);
    expect(controller.joinedBabies, isEmpty);

    await tester.pumpWidget(FairCareApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FairCare'), findsOneWidget);
    expect(find.text('FairCare · Today'), findsNothing);

    // Create the baby.
    final babyField = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == "Baby's name");
    await tester.enterText(babyField, 'Nyra');
    await tester.tap(find.widgetWithText(FilledButton, 'Create our baby'));
    await tester.pumpAndSettle();

    // The connect code is shown big; the role step and the finish
    // button are further down the scrollable onboarding screen.
    final baby = controller.selectedBaby!;
    expect(baby.name, 'Nyra');
    final code = repo.connectCodeFor(baby.id)!;
    expect(find.text(code), findsOneWidget);

    // Pick "Dad" as the default role (scroll it into view first —
    // the onboarding screen is one long ListView).
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dad'));
    await tester.pumpAndSettle();
    expect(controller.defaultCaregiverFor(baby.id)?.type,
        CaregiverType.father);

    // Finish → the shell (Today) appears.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start logging care'));
    await tester.pumpAndSettle();
    expect(find.text('FairCare · Today'), findsOneWidget);
  });
}
