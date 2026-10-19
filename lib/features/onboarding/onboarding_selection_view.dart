import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'onboarding_steps.dart';

class OnboardingSelectionView extends StatelessWidget {
  const OnboardingSelectionView({
    super.key,
    required this.app,
    required this.selected,
    required this.saving,
    required this.onToggle,
    required this.onContinue,
    required this.onSkip,
  });
  final AppState app;
  final Set<int> selected;
  final bool saving;
  final ValueChanged<int> onToggle;
  final VoidCallback onContinue, onSkip;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          ScreenHeading(
            title: 'ماذا تحفظ من القرآن؟',
            subtitle: 'اختر السور التي تحفظها كاملة.',
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingSteps(step: 0),
                const SizedBox(height: 16),
                const Text(
                  'يمكنك تعديل اختيارك في أي وقت.',
                  style: TextStyle(color: SuwarColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 14),
                for (final number in [1, 103, 108, 112, 113, 114])
                  Builder(
                    builder: (context) {
                      final surah = app.repository.surah(number);
                      return InkWell(
                        onTap: saving ? null : () => onToggle(number),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 70),
                          child: Row(
                            children: [
                              Rosette(
                                size: 38,
                                label: displayNumber(number),
                                color: SuwarColors.goldText,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      surah.name,
                                      style: headingStyle(context, size: 24),
                                    ),
                                    Text(
                                      '${displayNumber(surah.verseCount)} آيات',
                                      style: const TextStyle(
                                        color: SuwarColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox.square(
                                dimension: 48,
                                child: Center(
                                  child: Transform.scale(
                                    scale: 26 / 18,
                                    child: SizedBox.square(
                                      dimension: 48 * 18 / 26,
                                      child: Checkbox(
                                        value: selected.contains(number),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            7 * 18 / 26,
                                          ),
                                        ),
                                        onChanged: saving
                                            ? null
                                            : (_) => onToggle(number),
                                        semanticLabel:
                                            'أحفظ سورة ${surah.name}',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 9),
                Text(
                  selected.isEmpty
                      ? 'لم تحدد أي سورة بعد'
                      : 'اخترت ${displayNumber(selected.length)} سور',
                  style: const TextStyle(
                    color: SuwarColors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryAction(
                  label: saving ? 'جارٍ الحفظ…' : 'متابعة',
                  onPressed: saving ? null : onContinue,
                ),
                const SizedBox(height: 1),
                TextButton(
                  onPressed: saving ? null : onSkip,
                  child: const Text('سأحددها لاحقًا'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
