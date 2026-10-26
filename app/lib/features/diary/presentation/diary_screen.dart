import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/calorie_arc.dart';
import '../../../core/widgets/date_strip.dart';
import '../../../core/widgets/macro_bar.dart';
import '../../../l10n/app_strings.dart';
import '../../food/domain/food.dart';
import '../data/diary_repository.dart';
import '../domain/diary.dart';
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

  Future<void> _reload(DateTime day) async {
    ref.invalidate(diaryDayProvider(day));
    await ref.read(diaryDayProvider(day).future);
  }

  Future<void> _addFood(DateTime day, Meal meal, EnergyUnit unit) async {
    final food = await context.push<Food>(AppRoutes.foodSearch);
    if (food == null || !mounted) return;
    final saved = await context.push<bool>(
      AppRoutes.diaryEntry,
      extra: EntryEditorArgs.add(food: food, meal: meal, date: day, energyUnit: unit),
    );
    if (saved == true && mounted) ref.invalidate(diaryDayProvider(day));
  }

  Future<void> _edit(DiaryEntry entry, EnergyUnit unit) async {
    final saved = await context.push<bool>(
      AppRoutes.diaryEntry,
      extra: EntryEditorArgs.edit(entry, energyUnit: unit),
    );
    if (saved == true && mounted) ref.invalidate(diaryDayProvider(entry.date));
  }

  /// Hides the entry at once and deletes it on the server only when "undo" was not pressed.
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
        action: SnackBarAction(label: strings.undo, onPressed: () {}),
      ),
    );

    snackBar.closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) setState(() => _hidden.remove(entry.id));
        return;
      }
      try {
        await repository.delete(entry.id);
        if (mounted) await _reload(entry.date);
      } catch (_) {
        // Deleting failed: show the entry again so nothing is lost silently.
      }
      if (mounted) setState(() => _hidden.remove(entry.id));
    });
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
          isToday ? strings.today : MaterialLocalizations.of(context).formatMediumDate(day),
          key: const Key('home-title'),
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              key: const Key('open-debug'),
              tooltip: strings.debugTitle,
              icon: const Icon(Icons.developer_mode),
              onPressed: () => context.push(AppRoutes.debug),
            ),
          IconButton(
            key: const Key('logout'),
            tooltip: strings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
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
                  onAdd: (meal) => _addFood(day, meal, data.energyUnit),
                  onEdit: (entry) => _edit(entry, data.energyUnit),
                  onDelete: _delete,
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator(key: Key('diary-loading'))),
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
  });

  final DiaryDay day;
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
    final remaining = target == null ? null : target - totals.kcal;

    return ListView(
      key: const Key('diary-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              children: [
                CalorieArc(
                  progress: target == null || target <= 0 ? 0 : totals.kcal / target,
                  value: strings.energy(remaining?.abs() ?? totals.kcal, unit),
                  label: remaining == null
                      ? ''
                      : (remaining >= 0 ? strings.caloriesLeft : strings.caloriesOver),
                ),
                if (target != null && remaining != null)
                  Text(
                    strings.calorieFormula(
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
                      child: _macro(strings, strings.carbs, totals.carbs, targets.carbsG, colors.carbs),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _macro(strings, strings.fat, totals.fat, targets.fatG, colors.fat),
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
        for (final meal in Meal.values) ...[
          const SizedBox(height: 12),
          MealCard(
            meal: meal,
            energyText: strings.energy(day.totalsOf(meal).kcal, unit),
            onAdd: () => onAdd(meal),
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

  Widget _macro(AppStrings strings, String label, double grams, int? target, Color color) {
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
