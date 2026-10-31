import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/app/app.dart';
import 'package:tamra_app/app/locale_provider.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/activity/data/activity_repository.dart';
import 'package:tamra_app/features/activity/data/health_source.dart';
import 'package:tamra_app/features/activity/data/health_sync.dart';
import 'package:tamra_app/features/activity/domain/activity.dart';
import 'package:tamra_app/features/diary/data/diary_repository.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/features/onboarding/data/profile_repository.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';
import 'package:tamra_app/features/settings/data/file_sharer.dart';
import 'package:tamra_app/features/stats/data/stats_repository.dart';
import 'package:tamra_app/features/stats/domain/stats.dart';
import 'package:tamra_app/features/tracking/data/tracking_repository.dart';
import 'package:tamra_app/features/tracking/domain/tracking.dart';

/// Fixed language for widget tests.
class FixedLocale extends LocaleNotifier {
  FixedLocale(this.locale);

  final Locale locale;

  @override
  Locale? build() => locale;
}

/// Auth controller with a fixed state; records calls instead of talking to the API.
class FakeAuthController extends AuthController {
  FakeAuthController(this.initial, {this.loginError});

  final AuthState initial;
  final ApiError? loginError;
  final List<String> calls = [];

  @override
  AuthState build() => initial;

  @override
  Future<void> login(String email, String password) async {
    calls.add('login:$email');
    if (loginError != null) throw loginError!;
    state = const AuthState(status: AuthStatus.loggedIn);
  }

  @override
  Future<void> register(String email, String password) async {
    calls.add('register:$email');
    if (loginError != null) throw loginError!;
    state = const AuthState(
        status: AuthStatus.loggedIn, needsConsent: true, needsProfile: true);
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    state = const AuthState.loggedOut();
  }

  @override
  Future<void> accountDeleted() async {
    calls.add('accountDeleted');
    state = const AuthState.loggedOut();
  }
}

/// ApiClient whose methods return canned answers. No network.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(Dio());

  ApiError? loginError;
  ApiError? profileError;
  Map<String, dynamic> profile = {'is_complete': false};
  List<Map<String, dynamic>> consents = [];
  final List<String> calls = [];

  @override
  Future<AuthTokens> login(String email, String password) async {
    calls.add('login:$email');
    if (loginError != null) throw loginError!;
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<AuthTokens> register(String email, String password) async {
    calls.add('register:$email');
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<void> logout(String refreshToken) async =>
      calls.add('logout:$refreshToken');

  @override
  Future<Map<String, dynamic>> getProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<List<Map<String, dynamic>>> listConsents() async => consents;
}

/// Profile repository returning a fixed result.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(
      {this.result, this.fail = false, this.correctPassword = 'secret-pass-1'});

  Profile? result;
  final bool fail;
  final String correctPassword;
  OnboardingAnswers? saved;
  int consentCalls = 0;
  int withdrawCalls = 0;
  final List<Map<String, dynamic>> settingsChanges = [];
  final List<String> deletedWithPassword = [];

  @override
  Future<Profile> getProfile() async => result ?? const Profile();

  @override
  Future<Profile> updateSettings(Map<String, dynamic> changes) async {
    settingsChanges.add(changes);
    final old = result ?? const Profile();
    result = Profile(
      sex: old.sex,
      birthYear: old.birthYear,
      heightCm: old.heightCm,
      weightKg: old.weightKg,
      activityLevel: old.activityLevel,
      goal: old.goal,
      kcalTarget: old.kcalTarget,
      proteinG: old.proteinG,
      carbsG: old.carbsG,
      fatG: old.fatG,
      isComplete: old.isComplete,
      weightUnit: changes.containsKey('weight_unit')
          ? WeightUnit.fromApi(changes['weight_unit'])
          : old.weightUnit,
      energyUnit: changes.containsKey('energy_unit')
          ? EnergyUnit.fromApi(changes['energy_unit'])
          : old.energyUnit,
      language: changes['language']?.toString() ?? old.language,
      countActivityKcal: changes.containsKey('count_activity_kcal')
          ? changes['count_activity_kcal'] == true
          : old.countActivityKcal,
    );
    return result!;
  }

  @override
  Future<void> withdrawHealthConsent() async => withdrawCalls++;

  @override
  Future<String> exportData() async =>
      '{"account": {"email": "a@example.com"}}';

  @override
  Future<void> deleteAccount(String password) async {
    if (password != correctPassword) {
      throw const ApiError(
        code: 'validation_error',
        message: 'Invalid input.',
        fields: {
          'password': ['The password is not correct.'],
        },
        statusCode: 400,
      );
    }
    deletedWithPassword.add(password);
  }

  @override
  Future<Profile> saveOnboarding(OnboardingAnswers answers) async {
    if (fail) throw const ApiError(code: 'network_error', message: 'offline');
    saved = answers;
    return result ?? const Profile();
  }

  @override
  Future<void> giveHealthConsent() async {
    if (fail) throw const ApiError(code: 'network_error', message: 'offline');
    consentCalls++;
  }
}

/// Diary repository keeping entries in memory; records every call.
class FakeDiaryRepository implements DiaryRepository {
  FakeDiaryRepository({
    List<DiaryEntry>? entries,
    this.targets =
        const DayTargets(kcal: 2000, proteinG: 150, carbsG: 200, fatG: 67),
    this.energyUnit = EnergyUnit.kcal,
  }) : entries = entries ?? [];

  final List<DiaryEntry> entries;
  DayTargets targets;
  EnergyUnit energyUnit;
  Object? dayError;
  final List<DateTime> requestedDays = [];
  final List<NewDiaryEntry> added = [];
  final List<String> deleted = [];
  final List<String> updated = [];

  @override
  Future<DiaryDay> day(DateTime date) async {
    requestedDays.add(dateOnly(date));
    if (dayError != null) throw dayError!;
    return DiaryDay(
      date: dateOnly(date),
      entries: [
        for (final entry in entries)
          if (dateKey(entry.date) == dateKey(date)) entry,
      ],
      targets: targets,
      energyUnit: energyUnit,
    );
  }

  @override
  Future<DiaryEntry> add(NewDiaryEntry entry) async {
    added.add(entry);
    final saved = diaryEntry(
      id: 'new-${added.length}',
      date: entry.date,
      meal: entry.meal,
      name: 'Added',
      grams: entry.amountG,
      kcal: entry.amountG,
    );
    entries.add(saved);
    return saved;
  }

  @override
  Future<DiaryEntry> update(String id, {double? amountG, Meal? meal}) async {
    updated.add('$id:${amountG ?? '-'}:${meal?.name ?? '-'}');
    final index = entries.indexWhere((entry) => entry.id == id);
    final old = entries[index];
    final changed = diaryEntry(
      id: id,
      date: old.date,
      meal: meal ?? old.meal,
      name: old.foodName,
      grams: amountG ?? old.amountG,
      kcal: old.per100g.kcal * (amountG ?? old.amountG) / 100,
    );
    entries[index] = changed;
    return changed;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    entries.removeWhere((entry) => entry.id == id);
  }

  final List<String> copies = [];

  @override
  Future<int> copy(
      {required DateTime from, required DateTime to, Meal? meal}) async {
    copies.add('${dateKey(from)}>${dateKey(to)}:${meal?.name ?? 'all'}');
    final source = [
      for (final entry in entries)
        if (dateKey(entry.date) == dateKey(from) &&
            (meal == null || entry.meal == meal))
          entry,
    ];
    for (final entry in source) {
      entries.add(
        diaryEntry(
          id: '${entry.id}-copy',
          date: to,
          meal: entry.meal,
          name: entry.foodName,
          grams: entry.amountG,
          kcal: entry.nutrients.kcal,
        ),
      );
    }
    return source.length;
  }
}

/// A diary entry for tests; macros are derived from [kcal] in fixed shares.
DiaryEntry diaryEntry({
  required String id,
  required DateTime date,
  required Meal meal,
  required String name,
  required double grams,
  required double kcal,
}) {
  return DiaryEntry(
    id: id,
    date: date,
    meal: meal,
    foodId: 'food-$id',
    foodName: name,
    amountG: grams,
    nutrients: NutrientAmounts(
        kcal: kcal, protein: kcal / 20, carbs: kcal / 8, fat: kcal / 30),
  );
}

/// Weight and water kept in memory; records every call.
class FakeTrackingRepository implements TrackingRepository {
  final List<WeightLog> weightLogs = [];
  final Map<String, List<WaterLog>> waterByDay = {};
  final List<String> calls = [];
  var _nextId = 0;

  @override
  Future<List<WeightLog>> weights({required DateTime from}) async =>
      [...weightLogs]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<WeightLog> saveWeight(DateTime date, double weightKg) async {
    calls.add('weight:${dateKey(date)}:$weightKg');
    weightLogs.removeWhere((log) => dateKey(log.date) == dateKey(date));
    final log = WeightLog(
        id: 'w${_nextId++}', date: dateOnly(date), weightKg: weightKg);
    weightLogs.add(log);
    return log;
  }

  @override
  Future<void> deleteWeight(String id) async {
    calls.add('delete-weight:$id');
    weightLogs.removeWhere((log) => log.id == id);
  }

  @override
  Future<WaterDay> water(DateTime date) async =>
      WaterDay(date: dateOnly(date), entries: [...?waterByDay[dateKey(date)]]);

  @override
  Future<void> addWater(DateTime date, {int amountMl = glassMl}) async {
    calls.add('water+$amountMl');
    waterByDay.putIfAbsent(dateKey(date), () => []).insert(
          0,
          WaterLog(id: 'water${_nextId++}', amountMl: amountMl),
        );
  }

  @override
  Future<void> removeWater(String id) async {
    calls.add('water-$id');
    for (final entries in waterByDay.values) {
      entries.removeWhere((entry) => entry.id == id);
    }
  }
}

/// Workouts and steps kept in memory; records every call.
class FakeActivityRepository implements ActivityRepository {
  final List<Activity> activities = [];
  final Map<String, int> stepsByDay = {};
  final List<NewActivity> added = [];
  final List<String> deleted = [];
  final List<Map<String, dynamic>> imported = [];
  var _nextId = 0;

  @override
  Future<ActivityDay> day(DateTime date) async => ActivityDay(
        date: dateOnly(date),
        activities: [
          for (final activity in activities)
            if (dateKey(activity.date) == dateKey(date)) activity,
        ],
        steps: stepsByDay[dateKey(date)] ?? 0,
      );

  @override
  Future<Activity> add(NewActivity activity) async {
    added.add(activity);
    final saved = Activity(
      id: 'a${_nextId++}',
      date: activity.date,
      kind: activity.kind,
      durationMin: activity.durationMin,
      kcal: activity.kcal,
      distanceM: activity.distanceM,
    );
    activities.add(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    activities.removeWhere((activity) => activity.id == id);
  }

  @override
  Future<int> importData({
    required List<Map<String, dynamic>> activities,
    required List<Map<String, dynamic>> steps,
  }) async {
    imported.add({'activities': activities, 'steps': steps});
    return activities.length + steps.length;
  }
}

/// Health hub that returns prepared data and records permission requests.
class FakeHealthSource implements HealthSource {
  FakeHealthSource(
      {this.supported = true,
      this.grant = true,
      this.data = const HealthImport()});

  final bool supported;
  bool grant;
  HealthImport data;
  int permissionRequests = 0;
  final List<String> reads = [];

  @override
  bool get isSupported => supported;

  @override
  String get displayName => 'Health Connect';

  @override
  String get sourceApi => 'health_connect';

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<HealthImport> read(
      {required DateTime from, required DateTime to}) async {
    reads.add('${dateKey(from)}..${dateKey(to)}');
    return data;
  }
}

/// Statistics with a fixed answer.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository([this.result]);

  StatsSummary? result;
  Object? error;
  final List<String> calls = [];

  @override
  Future<StatsSummary> summary(DateTime from, DateTime to,
      {String group = 'day'}) async {
    calls.add('${dateKey(from)}..${dateKey(to)}:$group');
    if (error != null) throw error!;
    return result ??
        StatsSummary(
          days: [
            for (var offset = 0; offset <= to.difference(from).inDays; offset++)
              StatsDay(
                date: DateTime(from.year, from.month, from.day + offset),
                nutrients: const NutrientAmounts(),
              ),
          ],
          averages: const NutrientAmounts(),
        );
  }
}

/// Records shared files instead of opening the share menu.
class FakeFileSharer implements FileSharer {
  final List<String> sharedNames = [];
  final List<String> sharedContents = [];

  @override
  Future<void> shareJson(String fileName, String content) async {
    sharedNames.add(fileName);
    sharedContents.add(content);
  }
}

/// A tall phone screen so long lists (diary, profile) are built completely in tests.
void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

const loggedInComplete = AuthState(status: AuthStatus.loggedIn);

/// The whole app with a fixed language and auth state.
Widget testApp({
  Locale locale = const Locale('en'),
  AuthState auth = loggedInComplete,
  FakeAuthController? controller,
  FakeDiaryRepository? diary,
  FakeProfileRepository? profile,
  FakeTrackingRepository? tracking,
  FakeStatsRepository? stats,
  FakeFileSharer? sharer,
  FakeActivityRepository? activity,
  FakeHealthSource? health,
  MemoryHealthSettingsStorage? healthStorage,
  MemoryLanguageStorage? languageStorage,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(() => FixedLocale(locale)),
      authControllerProvider
          .overrideWith(() => controller ?? FakeAuthController(auth)),
      diaryRepositoryProvider.overrideWithValue(diary ?? FakeDiaryRepository()),
      profileRepositoryProvider
          .overrideWithValue(profile ?? FakeProfileRepository()),
      trackingRepositoryProvider
          .overrideWithValue(tracking ?? FakeTrackingRepository()),
      statsRepositoryProvider.overrideWithValue(stats ?? FakeStatsRepository()),
      fileSharerProvider.overrideWithValue(sharer ?? FakeFileSharer()),
      activityRepositoryProvider
          .overrideWithValue(activity ?? FakeActivityRepository()),
      healthSourceProvider.overrideWithValue(health ?? FakeHealthSource()),
      healthStorageProvider
          .overrideWithValue(healthStorage ?? MemoryHealthSettingsStorage()),
      languageStorageProvider
          .overrideWithValue(languageStorage ?? MemoryLanguageStorage()),
      ...overrides,
    ],
    child: const TamraApp(),
  );
}
