import 'package:faircare/app_controller.dart';
import 'package:faircare/main.dart';
import 'package:faircare/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the Today tab with the seeded baby',
      (tester) async {
    final repo = LocalFairCareRepository.memory();
    final controller = AppController(repo, MemoryKeyValueStore());
    await controller.init();

    await tester.pumpWidget(FairCareApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('FairCare · Today'), findsOneWidget);
    expect(find.text('Baby'), findsWidgets);
    expect(find.text('Log care'), findsOneWidget);
    expect(find.text('Nothing logged yet today.'), findsOneWidget);
  });

  testWidgets('bottom navigation reaches the Calendar tab',
      (tester) async {
    final repo = LocalFairCareRepository.memory();
    final controller = AppController(repo, MemoryKeyValueStore());
    await controller.init();

    await tester.pumpWidget(FairCareApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('FairCare · Calendar'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    // Month view: the summary card is on screen.
    expect(find.textContaining('logged this month'), findsOneWidget);
  });

  testWidgets('bottom navigation reaches Settings with default role section',
      (tester) async {
    final repo = LocalFairCareRepository.memory();
    final controller = AppController(repo, MemoryKeyValueStore());
    await controller.init();

    await tester.pumpWidget(FairCareApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Default role'), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
  });

  testWidgets('Appearance defaults to System and switches the app theme',
      (tester) async {
    final repo = LocalFairCareRepository.memory();
    final controller = AppController(repo, MemoryKeyValueStore());
    await controller.init();
    expect(controller.themeMode, ThemeMode.system);

    await tester.pumpWidget(FairCareApp(controller: controller));
    await tester.pumpAndSettle();

    MaterialApp app() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app().themeMode, ThemeMode.system);
    expect(app().darkTheme, isNotNull);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
    expect(app().themeMode, ThemeMode.dark);
    // The effective theme really is dark now.
    final context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.light);
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
