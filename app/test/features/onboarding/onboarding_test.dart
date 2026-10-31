import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';
import 'package:tamra_app/l10n/app_strings.dart';

import '../../helpers/fakes.dart';

void main() {
  group('consent screen', () {
    testWidgets('button is disabled until the box is checked', (tester) async {
      final repository = FakeProfileRepository();
      final controller = FakeAuthController(
        const AuthState(
            status: AuthStatus.loggedIn,
            needsConsent: true,
            needsProfile: true),
      );
      await tester.pumpWidget(
        testApp(
          controller: controller,
          profile: repository,
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('consent-continue'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.byKey(const Key('consent-checkbox')));
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(repository.consentCalls, 1);
      // next step: onboarding questions
      expect(find.byKey(const Key('onboarding-step')), findsOneWidget);
    });
  });

  group('onboarding', () {
    const serverProfile = Profile(
      kcalTarget: 1742,
      proteinG: 131,
      carbsG: 174,
      fatG: 58,
      isComplete: true,
    );

    Future<FakeProfileRepository> openOnboarding(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final repository = FakeProfileRepository(result: serverProfile);
      await tester.pumpWidget(
        testApp(
          locale: locale,
          auth:
              const AuthState(status: AuthStatus.loggedIn, needsProfile: true),
          profile: repository,
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> tapNext(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }

    Future<void> enter(WidgetTester tester, String value) async {
      await tester.enterText(find.byKey(const Key('onboarding-input')), value);
      await tapNext(tester);
    }

    testWidgets('happy path saves the answers and shows the target',
        (tester) async {
      final repository = await openOnboarding(tester);
      final year = DateTime.now().year;

      await tester.tap(find.byKey(Key('choice-${WeightGoal.maintain}')));
      await tapNext(tester);
      await tester.tap(find.byKey(Key('choice-${Sex.female}')));
      await tapNext(tester);
      await enter(tester, '${year - 30}');
      await enter(tester, '170');
      await enter(tester, '70,0');
      await tester.tap(find.byKey(Key('choice-${ActivityLevel.sedentary}')));
      await tapNext(tester);

      expect(repository.saved?.toJson(), {
        'goal': 'maintain',
        'sex': 'female',
        'birth_year': year - 30,
        'height_cm': '170.0',
        'weight_kg': '70.0',
        'activity_level': 'sedentary',
      });
      expect(find.text('1742 kcal per day'), findsOneWidget);
      expect(find.text('131 g'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-title')), findsOneWidget);
    });

    testWidgets('a goal must be chosen before going on', (tester) async {
      await openOnboarding(tester);
      await tapNext(tester);
      expect(find.text('Step 1 of 6'), findsOneWidget);
    });

    testWidgets('height outside 100–250 shows an error', (tester) async {
      await openOnboarding(tester);
      final year = DateTime.now().year;
      await tester.tap(find.byKey(Key('choice-${WeightGoal.lose}')));
      await tapNext(tester);
      await tester.tap(find.byKey(Key('choice-${Sex.male}')));
      await tapNext(tester);
      await enter(tester, '${year - 40}');
      await enter(tester, '50');

      expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
      expect(find.text('Please enter a value between 100 and 250.'),
          findsOneWidget);
      expect(find.text('Step 4 of 6'), findsOneWidget);
    });

    testWidgets('Arabic onboarding is right-to-left', (tester) async {
      await openOnboarding(tester, locale: const Locale('ar'));
      final step = find.byKey(const Key('onboarding-step'));
      expect(Directionality.of(tester.element(step)), TextDirection.rtl);
      expect(find.text(AppStrings(const Locale('ar')).goalQuestion),
          findsOneWidget);
    });
  });

  test('OnboardingAnswers maps very active to the API value', () {
    expect(OnboardingAnswers.activityToApi(ActivityLevel.veryActive),
        'very_active');
  });

  test('Profile.fromJson reads DRF decimals', () {
    final profile = Profile.fromJson({
      'sex': 'female',
      'birth_year': 1990,
      'height_cm': '170.5',
      'weight_kg': '70.0',
      'kcal_target': 1742,
      'is_complete': true,
    });
    expect(profile.heightCm, 170.5);
    expect(profile.weightKg, 70.0);
    expect(profile.isComplete, isTrue);
    expect(Profile.fromJson({'sex': ''}).sex, isNull);
  });

  test('local target matches the shared formula', () {
    const answers = OnboardingAnswers(
      goal: WeightGoal.maintain,
      sex: Sex.female,
      birthYear: 1996,
      heightCm: 170,
      weightKg: 70,
      activityLevel: ActivityLevel.sedentary,
    );
    expect(answers.localCalorieTarget(2026), 1742);
  });
}
