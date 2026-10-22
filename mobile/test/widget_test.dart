import 'package:faircare/app_controller.dart';
import 'package:faircare/main.dart';
import 'package:faircare/repository.dart';
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
}
