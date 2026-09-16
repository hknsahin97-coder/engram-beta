// End-to-end verification of the review flow: is every card reachable, does a
// rating move to the next card, does the closing screen appear?
//
// It needs real Isar so it lives in integration_test; free to run on Android:
//     flutter test integration_test/review_flow_test.dart -d <device>
import 'package:engram/core/theme/app_theme.dart';
import 'package:engram/core/theme/theme_controller.dart';
import 'package:engram/data/local/isar_service.dart';
import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/repositories/isar_card_repository.dart';
import 'package:engram/features/review/review_screen.dart';
import 'package:engram/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    isar = await IsarService.open(
      directory: dir.path,
      name: 'review_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
  });

  Future<void> seed(List<String> prompts) async {
    final repo = IsarCardRepository(isar);
    for (final p in prompts) {
      await repo.add(MemoryCard.create(type: CardType.text, prompt: p));
    }
  }

  Future<void> pumpReview(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: AppTheme.light(),
          home: const Scaffold(body: ReviewScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state when there are no cards', (tester) async {
    await pumpReview(tester);
    expect(find.text('Nothing to review right now'), findsOneWidget);
  });

  testWidgets('every card is reachable by swiping', (tester) async {
    // This is the real question: does any card get lost in the swipe flow?
    await seed(['first card', 'second card', 'third card']);
    await pumpReview(tester);

    expect(find.text('first card'), findsOneWidget);

    for (final next in ['second card', 'third card']) {
      await tester.drag(find.byType(PageView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text(next), findsOneWidget, reason: 'could not reach card $next');
    }

    // The closing screen is NOT expected here: nothing has been rated, so that
    // page does not exist yet. A separate test verifies it.
  });

    testWidgets('tapping reveals the answer and brings up the buttons', (tester) async {
    await seed(['capital of France']);
    final repo = IsarCardRepository(isar);
    final card = (await repo.list()).single;
    card.answer = 'Paris';
    await repo.update(card);

    await pumpReview(tester);

    // The answer must not show before it is revealed, or nobody can self-test.
    expect(find.text('Paris'), findsNothing);

    await tester.tap(find.text('capital of France'));
    await tester.pumpAndSettle();

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('a rating moves to the next card', (tester) async {
    // Regression: when the queue provider refreshed, the PageView was
    // removed from the screen and nothing after the first card could be
    // reviewed.
    await seed(['card A', 'card B']);
    await pumpReview(tester);

    await tester.tap(find.text('card A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('card B'), findsOneWidget);
    expect(find.text('card A'), findsNothing);

    // Rate the second one too -> the closing screen.
    await tester.tap(find.text('card B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text("That's it for today"), findsOneWidget);
  });

  // The closing screen must not be reachable by skipping cards: that page
  // exists only once everything has been rated.
  testWidgets('the closing screen is unreachable while a card is unrated',
      (tester) async {
    await seed(['card 1', 'card 2', 'card 3']);
    await pumpReview(tester);

    // Swipe to the end without rating anything.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(PageView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    expect(find.text("That's it for today"), findsNothing,
        reason: 'skipping should not reach the finish screen');
    expect(find.text('card 3'), findsOneWidget);
  });

  testWidgets('a skipped card is offered again', (tester) async {
    await seed(['card 1', 'card 2']);
    await pumpReview(tester);

    // Skip the first, rate the second -> it should wrap round to the first.
    await tester.drag(find.byType(PageView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('card 2'), findsOneWidget);

    await tester.tap(find.text('card 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('card 1'), findsOneWidget,
        reason: 'a skipped card has to come back round');
    expect(find.text("That's it for today"), findsNothing);
  });

  testWidgets('a rating is written persistently', (tester) async {
    await seed(['card to rate']);
    await pumpReview(tester);

    await tester.tap(find.text('card to rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    final repo = IsarCardRepository(isar);
    final card = (await repo.list()).single;
    expect(card.reps, 1);
    expect(card.lapses, 0);
    expect((await repo.logsFor(card.id)).length, 1);
  });

  testWidgets('with the cap in effect the closing screen does not say "nothing left"',
      (tester) async {
    // Daily cap 2, four pending: when the session ends it has to say other
    // cards are waiting but give NO NUMBER. The explanatory sentence is shown
    // once only.
    SharedPreferences.setMockInitialValues({'daily_cap': 2});
    prefs = await SharedPreferences.getInstance();

    await seed(['card 1', 'card 2', 'card 3', 'card 4']);
    await pumpReview(tester);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    }

    expect(find.text("That's it for today"), findsOneWidget);
    expect(find.text('Nothing else is due'), findsNothing,
        reason: 'with the cap in effect this sentence is not true');
    expect(find.text("There's more waiting"), findsOneWidget);
    expect(
      find.textContaining('raise the daily limit'),
      findsOneWidget,
      reason: 'the one-time explanation should appear the first time',
    );
  });

  testWidgets('the cap reminder is not shown a second time', (tester) async {
    SharedPreferences.setMockInitialValues({
      'daily_cap': 2,
      'daily_cap_hint_shown': true,
    });
    prefs = await SharedPreferences.getInstance();

    await seed(['card 1', 'card 2', 'card 3', 'card 4']);
    await pumpReview(tester);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    }

    // "There is more" is permanent (always true); the explanation is one-time.
    expect(find.text("There's more waiting"), findsOneWidget);
    expect(find.textContaining('raise the daily limit'), findsNothing);
  });
}
