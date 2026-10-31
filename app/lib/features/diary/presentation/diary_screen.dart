import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/calorie_arc.dart';
import '../../../core/widgets/date_strip.dart';
import '../../../core/widgets/macro_bar.dart';
import '../../../l10n/app_strings.dart';
import '../../food/domain/food.dart';
import '../../tracking/presentation/water_card.dart';
import '../data/diary_repository.dart';
import '../domain/diary.dart';
import 'add_food_flow.dart';
import 'entry_editor_screen.dart';
import 'meal_card.dart';

/// How long a deleted entry can be restored with "undo".
const undoDuration = Duration(seconds: 4);

/// Start screen: the diary of one day with calories, macros and the four meals.
class DiaryScreen extends ConsumerStatefulWidget {
  /// Creates the diary screen.
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  /// Entries deleted on screen whose delete can still be undone.
  final Set<String> _hidden = {};

  /// Deletes waiting for [undoDuration]: the timer and the action that deletes on the server.
  final Map<String, ({Timer timer, Future<void> Function() commit})> _pending =
      {};

  Future<void> _reload(DateTime day) async {
    ref.invalidate(diaryDayProvider(day));
    await ref.read(diaryDayProvider(day).future);
  }

  Future<void> _addFood(Meal meal) async {
    final food = await context.push<Food>(AppRoutes.foodSearch);
    if (food == null || !mounted) return;
    await addFoodToDiary(context, ref, food: food, meal: meal);
  }

  Future<void> _edit(DiaryEntry entry, EnergyUnit unit) async {
    final saved = await context.push<bool>(
      AppRoutes.diaryEntry,
      extra: EntryEditorArgs.edit(entry, energyUnit: unit),
    );
    if (saved == true && mounted) ref.invalidate(diaryDayProvider(entry.date));
  }

  /// Copies the day before (or only [meal]) onto [day] and reports how many entries came.
  Future<void> _copyFromYesterday(DateTime day, {Meal? meal}) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yesterday = DateTime(day.year, day.month, day.day - 1);
    try {
      final copied = await ref.read(diaryRepositoryProvider).copy(
            from: yesterday,
            to: day,
            meal: meal,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(copied == 0
              ? strings.nothingToCopy
              : strings.entriesCopied(copied)),
        ),
      );
      if (copied > 0 && mounted) await _reload(day);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.genericError)));
    }
  }

  /// Hides the entry at once; it is deleted on the server after [undoDuration] unless
  /// "undo" is pressed. A timer decides, not the snack bar: snack bars with an action
  /// stay open until they are touched (accessibility), so they cannot be the trigger.
  void _delete(DiaryEntry entry) {
    final strings = AppStrings.of(context);
    final repository = ref.read(diaryRepositoryProvider);
    setState(() => _hidden.add(entry.id));

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        key: const Key('undo-snackbar'),
        content: Text(strings.entryDeleted),
        duration: undoDuration,
        action: SnackBarAction(
            label: strings.undo, onPressed: () => _undo(entry.id)),
      ),
    );

    var snackBarOpen = true;
    snackBar.closed.then((_) => snackBarOpen = false);

    Future<void> commit() async {
      _pending.remove(entry.id);
      if (snackBarOpen) snackBar.close();
      try {
        await repository.delete(entry.id);
        if (mounted) await _reload(entry.date);
      } catch (_) {
        // Deleting failed: show the entry again so nothing is lost silently.
      }
      if (mounted) setState(() => _hidden.remove(entry.id));
    }

    _pending[entry.id] = (timer: Timer(undoDuration, commit), commit: commit);
  }

  /// Restores an entry whose delete is still pending.
  void _undo(String id) {
    _pending.remove(id)?.timer.cancel();
    if (mounted) setState(() => _hidden.remove(id));
  }

  @override
  void dispose() {
    // Leaving the screen confirms pending deletes instead of dropping them.
    for (final pending in [..._pending.values]) {
      pending.timer.cancel();
      pending.commit();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final day = ref.watch(selectedDayProvider);
    final diary = ref.watch(diaryDayProvider(day));
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isToday
              ? strings.today
              : MaterialLocalizations.of(context).formatMediumDate(day),
          key: const Key('home-title'),
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('diary-menu'),
            tooltip: strings.moreOptions,
            onSelected: (_) => _copyFromYesterday(day),
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('copy-yesterday'),
                value: 'copy-yesterday',
                child: Text(strings.copyYesterday),
              ),
            ],
          ),
          if (kDebugMode)
            IconButton(
              key: const Key('open-debug'),
              tooltip: strings.debugTitle,
              icon: const Icon(Icons.developer_mode),
              onPressed: () => context.push(AppRoutes.debug),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: DateStrip(
              selected: day,
              onSelected: ref.read(selectedDayProvider.notifier).select,
            ),
          ),
          Expanded(
            child: diary.when(
              data: (data) => RefreshIndicator(
                onRefresh: () => _reload(day),
                child: _DiaryContent(
                  day: data.without(_hidden),
                  onAdd: _addFood,
                  onCopyMeal: (meal) => _copyFromYesterday(day, meal: meal),
                  onEdit: (entry) => _edit(entry, data.energyUnit),
                  onDelete: _delete,
                ),
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(key: Key('diary-loading'))),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(strings.genericError, key: const Key('diary-error')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('diary-retry'),
                      onPressed: () => ref.invalidate(diaryDayProvider(day)),
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryContent extends StatelessWidget {
  const _DiaryContent({
    required this.day,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyMeal,
  });

  final DiaryDay day;
  final ValueChanged<Meal> onCopyMeal;
  final ValueChanged<Meal> onAdd;
  final ValueChanged<DiaryEntry> onEdit;
  final ValueChanged<DiaryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final totals = day.totals;
    final unit = day.energyUnit;
    final targets = day.targets;
    final target = targets.kcal;
    final budget = day.budget;
    final remaining = budget == null ? null : budget - totals.kcal;
    final sport = day.countedSportKcal;

    return ListView(
      key: const Key('diary-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        if (day.offline)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Row(
              key: const Key('diary-offline'),
              children: [
                Icon(Icons.cloud_off, size: 18, color: colors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(strings.offlineHint,
                      style: TextStyle(color: colors.textSecondary)),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              children: [
                CalorieArc(
                  progress:
                      budget == null || budget <= 0 ? 0 : totals.kcal / budget,
                  value: strings.energy(remaining?.abs() ?? totals.kcal, unit),
                  label: remaining == null
                      ? ''
                      : (remaining >= 0
                          ? strings.caloriesLeft
                          : strings.caloriesOver),
                ),
                if (target != null && remaining != null)
                  Text(
                    sport > 0
                        ? strings.calorieFormulaSport(
                            target: strings.energy(target.toDouble(), unit),
                            sport: strings.energy(sport, unit),
                            eaten: strings.energy(totals.kcal, unit),
                            remaining: strings.energy(remaining, unit),
                          )
                        : strings.calorieFormula(
                            target: strings.energy(target.toDouble(), unit),
                            eaten: strings.energy(totals.kcal, unit),
                            remaining: strings.energy(remaining, unit),
                          ),
                    key: const Key('calorie-formula'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _macro(strings, strings.carbs, totals.carbs,
                          targets.carbsG, colors.carbs),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _macro(strings, strings.fat, totals.fat,
                          targets.fatG, colors.fat),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _macro(
                        strings,
                        strings.protein,
                        totals.protein,
                        targets.proteinG,
                        colors.protein,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (day.burnedKcal > 0 || day.steps > 0) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('diary-sport'),
              leading: Icon(Icons.directions_run, color: colors.brand),
              title: Text(
                  strings.activityBurned(strings.energy(day.burnedKcal, unit))),
              trailing: Text(strings.stepsValue(day.steps)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        WaterCard(day: day.date),
        for (final meal in Meal.values) ...[
          const SizedBox(height: 12),
          MealCard(
            meal: meal,
            energyText: strings.energy(day.totalsOf(meal).kcal, unit),
            onAdd: () => onAdd(meal),
            onCopyFromYesterday: () => onCopyMeal(meal),
            children: [
              for (final entry in day.entriesOf(meal))
                Dismissible(
                  key: ValueKey('dismiss-${entry.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    color: colors.border,
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => onDelete(entry),
                  child: ListTile(
                    key: Key('entry-${entry.id}'),
                    contentPadding: EdgeInsetsDirectional.zero,
                    title: Text(entry.foodName),
                    subtitle: Text(strings.gramsValue(entry.amountG.round())),
                    trailing: Text(strings.energy(entry.nutrients.kcal, unit)),
                    onTap: () => onEdit(entry),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _macro(AppStrings strings, String label, double grams, int? target,
      Color color) {
    return MacroBar(
      label: label,
      grams: grams,
      target: target,
      color: color,
      amountText: target == null
          ? strings.gramsValue(grams.round())
          : strings.gramsProgress(grams.round(), target),
    );
  }
}
