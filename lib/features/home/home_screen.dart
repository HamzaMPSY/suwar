import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../memory/learning_screen.dart';
import '../passages/passage_scope.dart';
import '../passages/passage_read_screen.dart';
import '../passages/recitation_target.dart';
import '../prayer/prayer_format.dart';
import '../prayer/prayer_review_screen.dart';
import '../prayer/prayer_runtime.dart';
import '../prayer/prayer_widgets.dart';
import '../prayer/reminder_payload.dart';
import '../quran/reader_screen.dart';
import '../settings/settings_screen.dart';
import 'personal_home_actions.dart';
import 'suggestion_states.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.onBrowse,
    this.prayer,
    this.onPrayers,
  });
  final AppState state;
  final VoidCallback onBrowse;
  final PrayerRuntime? prayer;
  final VoidCallback? onPrayers;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final random = Random();
  List<RecitationTarget> pair = [];
  String? knownKey;

  void review() {
    final app = widget.state;
    final runtime = widget.prayer;
    final now = DateTime.now().toUtc();
    final next = runtime?.state.calculator.next(runtime.state.settings, now);
    final subtitle = next == null
        ? null
        : '${next.kind.label} · ${prayerClock(runtime!.state.calculator.localTime(runtime.state.settings, next.timeUtc))}';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          if (pair.isEmpty) return EmptySuggestionsScreen(state: app);
          if (pair.length == 1 && !pair.first.isPassage) {
            return SingleSuggestionScreen(state: app, subtitle: subtitle);
          }
          return PrayerReviewScreen(
            app: app,
            tap: ReminderTap(
              targets: pair.map((s) => s.reference).toList(),
              prayer: next?.kind.name ?? 'test',
            ),
            subtitle: subtitle,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.state,
      ?widget.prayer?.state,
      ?PassageScope.maybeOf(context),
    ]),
    builder: (context, _) {
      final app = widget.state;
      final eligible = eligibleRecitations(app, PassageScope.maybeOf(context));
      final key = eligible
          .map((t) => '${t.reference.fingerprint}:${t.name}')
          .join('|');
      if (knownKey != key) {
        knownKey = key;
        pair = selectRecitations(eligible, random);
      }
      if (pair.isEmpty) {
        return EmptySuggestionsContent(
          state: app,
          onBrowse: widget.onBrowse,
          footer: PersonalHomeActions(app: app),
          trailing: IconButton(
            tooltip: 'الإعدادات',
            icon: const SuwarIcon(SuwarSymbol.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SettingsScreen(state: app, prayer: widget.prayer),
              ),
            ),
          ),
        );
      }
      final prayer = widget.prayer?.state;
      final local = prayer?.calculator.localNow(
        prayer.settings,
        DateTime.now().toUtc(),
      );
      final learningId = app.learningSurahId;
      return ListView(
        key: const PageStorageKey('today'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeading(
            title: 'السلام عليكم',
            subtitle: local == null
                ? 'رحلتك مع القرآن، كل يوم'
                : '${prayerDate(local).replaceFirst(' ${displayNumber(local.year)}', '')} · ${prayer!.settings.city.name}',
            trailing: IconButton(
              tooltip: 'الإعدادات',
              icon: const SuwarIcon(SuwarSymbol.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SettingsScreen(state: app, prayer: widget.prayer),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (prayer != null)
                  NextPrayerCard(state: prayer, onTap: review)
                else
                  Container(
                    constraints: const BoxConstraints(minHeight: 190),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: SuwarColors.green,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'محفوظاتك',
                          style: TextStyle(color: SuwarColors.sage),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${displayNumber(app.memorizedIds.length)} سور من 114',
                          style: headingStyle(
                            context,
                            size: 32,
                            color: SuwarColors.paper,
                          ),
                        ),
                        const Text(
                          'اقرأ وراجع دون اتصال',
                          style: TextStyle(color: SuwarColors.sage),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  pair.any((t) => t.isPassage)
                      ? 'اقتراحات لصلاتك القادمة'
                      : pair.length == 1
                      ? 'سورة لصلاتك القادمة'
                      : 'سورتان لصلاتك القادمة',
                  style: headingStyle(context, size: 22),
                ),
                const SizedBox(height: 10),
                _pair(context),
                const SizedBox(height: 18),
                PrimaryAction(
                  label: pair.any((t) => t.isPassage)
                      ? 'راجع اقتراحاتك'
                      : pair.length == 1
                      ? 'راجع سورتك'
                      : 'راجع السورتين',
                  onPressed: review,
                ),
                const SizedBox(height: 20),
                Text('واصل الحفظ', style: headingStyle(context, size: 20)),
                if (learningId != null)
                  Semantics(
                    container: true,
                    button: true,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LearningScreen(
                            state: app,
                            surah: app.repository.surah(learningId),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const SuwarIcon(SuwarSymbol.learning, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'سورة ${app.repository.surah(learningId).name}',
                                    style: headingStyle(context, size: 21),
                                  ),
                                  Text(
                                    'الآية ${displayNumber(app.learningAyahIndex + 1)} من ${displayNumber(app.repository.surah(learningId).verseCount)} · جلسة قصيرة',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SuwarColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SuwarIcon(SuwarSymbol.back, size: 20),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: widget.onBrowse,
                    child: const Text('اختر سورة لتبدأ حفظها'),
                  ),
                const SizedBox(height: 24),
                PersonalHomeActions(app: app),
                TextButton(
                  onPressed: widget.onBrowse,
                  child: const Text('تصفّح القرآن الكريم'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _pair(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 116),
    decoration: BoxDecoration(
      color: SuwarColors.paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SuwarColors.line),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < pair.length; i++) ...[
            if (i > 0)
              const VerticalDivider(width: 1, indent: 24, endIndent: 24),
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => pair[i].isPassage
                          ? PassageReadScreen(
                              app: widget.state,
                              range: pair[i].range,
                              name: pair[i].name,
                            )
                          : ReaderScreen(
                              state: widget.state,
                              surah: widget.state.repository.surah(
                                pair[i].range.surahId,
                              ),
                            ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pair[i].name,
                          textAlign: TextAlign.center,
                          style: headingStyle(context, size: 29),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          pair[i].isPassage
                              ? pair[i].metadata
                              : '${displayNumber(widget.state.repository.surah(pair[i].range.surahId).verseCount)} آيات · محفوظة',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
