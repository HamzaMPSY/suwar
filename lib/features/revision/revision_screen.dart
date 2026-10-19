import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../onboarding/known_selection_screen.dart';
import '../quran/reader_screen.dart';
import 'revision_state.dart';
import 'revision_selection_screen.dart';

class RevisionScreen extends StatelessWidget {
  const RevisionScreen({super.key, required this.state});
  final RevisionState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final surahs = state.app.repository.surahs
              .where((s) => state.activeIds.contains(s.number))
              .toList();
          void choose() => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => state.app.memorizedIds.isEmpty
                  ? KnownSelectionScreen(state: state.app)
                  : RevisionSelectionScreen(state: state),
            ),
          );
          return ListView(
            children: [
              ScreenHeading(
                title: 'مراجعتي اليوم',
                subtitle: surahs.isEmpty
                    ? 'خطوة قصيرة من محفوظاتك'
                    : 'حسب يوم مدينتك المختارة · ${state.prayer.settings.city.name}',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (surahs.isEmpty) ...[
                      const SizedBox(height: 103),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 70),
                        child: Text(
                          'اختر ما تريد مراجعته',
                          textAlign: TextAlign.center,
                          style: headingStyle(context, size: 28),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 90),
                        child: const Text(
                          'تظهر هنا السور المحفوظة التي تختارها فقط.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 70),
                      PrimaryAction(
                        label: state.app.memorizedIds.isEmpty
                            ? 'تحديد السور التي أحفظها'
                            : 'اختيار سور من حفظي',
                        onPressed: choose,
                      ),
                    ] else ...[
                      const SizedBox(height: 33),
                      Text(
                        'اخترت ${displayNumber(surahs.length)} سور لمراجعتها · ${displayNumber(state.completedToday.length)} اكتملت',
                        style: headingStyle(context, size: 20),
                      ),
                      const SizedBox(height: 47),
                      for (final surah in surahs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 42),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReaderScreen(
                                        state: state.app,
                                        surah: surah,
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    alignment: AlignmentDirectional.centerStart,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: Text(
                                    surah.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: SuwarColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'إكمال مراجعة ${surah.name}',
                                child: Switch(
                                  value: state.completedToday.contains(
                                    surah.number,
                                  ),
                                  onChanged: (_) => state.toggle(surah.number),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 25),
                      PrimaryAction(
                        label: 'اختيار سور المراجعة',
                        secondary: true,
                        backgroundColor: SuwarColors.paper,
                        onPressed: choose,
                      ),
                      const SizedBox(height: 74),
                      const DesignNotice(
                        minHeight: 140,
                        message:
                            'التقييم ذاتي. يمكنك التراجع عن الإكمال، وتبدأ علامات يوم جديد دون حذف اختياراتك.',
                      ),
                    ],
                    if (state.error != null) ...[
                      const SizedBox(height: 24),
                      Text(state.error!),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
