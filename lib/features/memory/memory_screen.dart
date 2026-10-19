import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../quran/reader_screen.dart';
import 'learning_screen.dart';
import '../passages/passage_scope.dart';
import '../passages/passages_screen.dart';
import '../passages/passage_widgets.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    required this.state,
    required this.onBrowse,
    this.initialPassages = false,
  });
  final AppState state;
  final VoidCallback onBrowse;
  final bool initialPassages;
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late bool showPassages;
  int? previousLearning;
  int? completedSurah;
  @override
  void initState() {
    super.initState();
    showPassages = widget.initialPassages;
    previousLearning = widget.state.learningSurahId;
    widget.state.addListener(_changed);
  }

  void _changed() {
    final app = widget.state;
    if (previousLearning != null &&
        app.learningSurahId == null &&
        app.memorizedIds.contains(previousLearning)) {
      completedSurah = previousLearning;
      showPassages = false;
    }
    if (app.learningSurahId != null) completedSurah = null;
    if (completedSurah != null && !app.memorizedIds.contains(completedSurah)) {
      completedSurah = null;
    }
    previousLearning = app.learningSurahId;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.state;
    final passages = PassageScope.maybeOf(context);
    if (showPassages && passages != null) {
      return PassagesScreen(
        app: app,
        embedded: true,
        onShowSurahs: () => setState(() => showPassages = false),
      );
    }
    final known = app.repository.surahs
        .where((s) => app.memorizedIds.contains(s.number))
        .toList();
    if (completedSurah != null) {
      known.sort(
        (a, b) => a.number == completedSurah
            ? -1
            : b.number == completedSurah
            ? 1
            : a.number.compareTo(b.number),
      );
    }
    final learningId = app.learningSurahId;
    final learning = learningId == null
        ? null
        : app.repository.surah(learningId);
    return ListView(
      key: const PageStorageKey('memory'),
      children: [
        const ScreenHeading(
          title: 'حفظي',
          subtitle: 'كل آية تحفظها، تبقى معك.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (passages != null) ...[
                MemorySectionTabs(
                  passages: false,
                  onChanged: (value) => setState(() => showPassages = value),
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 135),
                padding: const EdgeInsets.fromLTRB(22, 13, 22, 21),
                decoration: BoxDecoration(
                  color: SuwarColors.green,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'محفوظاتك',
                      style: TextStyle(color: Color(0xFFD1D7C8), fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${displayNumber(known.length)} سور من 114',
                      style: headingStyle(
                        context,
                        size: 28,
                        color: SuwarColors.paper,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Semantics(
                      label: 'حفظت ${displayNumber(known.length)} من 114 سورة',
                      child: LinearProgressIndicator(
                        value: known.length / 114,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        color: SuwarColors.gold,
                        backgroundColor: const Color(0xFF49705E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text('أحفظها الآن', style: headingStyle(context, size: 24)),
              const SizedBox(height: 14),
              if (learning != null)
                LearningSummaryCard(app: app, surah: learning)
              else if (completedSurah != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 111),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'أضفت سورة ${app.repository.surah(completedSurah!).name} إلى محفوظاتك.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: SuwarColors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryAction(
                        label: 'اختر سورة جديدة',
                        secondary: true,
                        onPressed: widget.onBrowse,
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 111),
                  child: Center(
                    child: PrimaryAction(
                      label: 'اختر سورة جديدة',
                      secondary: true,
                      onPressed: widget.onBrowse,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              Text('سور أحفظها', style: headingStyle(context, size: 24)),
              const SizedBox(height: 8),
              if (known.isEmpty)
                const Text(
                  'لم تحدد أي سورة محفوظة بعد.',
                  style: TextStyle(color: SuwarColors.muted),
                )
              else
                _knownRow(context, known.first),
              const SizedBox(height: 16),
              PrimaryAction(
                label: 'إدارة محفوظاتي',
                secondary: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => KnownSelectionScreen(state: app),
                  ),
                ),
              ),
              if (known.length > 1) ...[
                const SizedBox(height: 32),
                for (final surah in known.skip(1)) _knownRow(context, surah),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  Widget _knownRow(BuildContext context, Surah surah) => Column(
    children: [
      SurahTile(
        surah: surah,
        memorized: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(state: widget.state, surah: surah),
          ),
        ),
      ),
      const Divider(),
    ],
  );
}

class LearningSummaryCard extends StatelessWidget {
  const LearningSummaryCard({
    super.key,
    required this.app,
    required this.surah,
  });
  final AppState app;
  final Surah surah;
  @override
  Widget build(BuildContext context) => Material(
    color: SuwarColors.paper,
    borderRadius: BorderRadius.circular(18),
    child: Semantics(
      container: true,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LearningScreen(state: app, surah: surah),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 111),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: SuwarColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Rosette(
                size: 42,
                label: displayNumber(surah.number),
                color: SuwarColors.goldText,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سورة ${surah.name}',
                      style: headingStyle(context, size: 27),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${displayNumber(surah.verseCount)} آيات · ${app.learningAyahIndex == 0 ? 'ابدأ بآية واحدة' : 'متابعة من الآية ${displayNumber(app.learningAyahIndex + 1)}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: SuwarColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const SuwarIcon(SuwarSymbol.back, size: 23),
            ],
          ),
        ),
      ),
    ),
  );
}
