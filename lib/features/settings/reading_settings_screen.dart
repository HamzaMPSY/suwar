import 'package:flutter/material.dart';
import '../../core/quran_presentation.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ReadingSettingsScreen extends StatelessWidget {
  const ReadingSettingsScreen({
    super.key,
    required this.state,
    this.fontSettings = false,
  });
  final AppState state;
  final bool fontSettings;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          children: [
            ScreenHeading(
              title: fontSettings ? 'حجم النص القرآني' : 'رواية القرآن',
              subtitle: fontSettings
                  ? 'اختر حجمًا يناسب قراءتك.'
                  : 'تظهر النصوص والتلاوات بحسب الرواية المختارة.',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 55),
                  if (!fontSettings) ...[
                    _reading(context, 'ورش عن نافع', 'الرواية الحالية', true),
                    const SizedBox(height: 22),
                    _reading(
                      context,
                      'حفص عن عاصم',
                      'غير متاحة في هذه النسخة',
                      false,
                    ),
                    const SizedBox(height: 60),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 70),
                      child: const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'يتبع النص وترقيم الآيات والتلاوة روايتك.',
                          style: TextStyle(
                            fontSize: 15,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 134),
                    PrimaryAction(
                      label: 'حفظ الاختيار',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ] else ...[
                    Slider(
                      value: state.quranFontSize,
                      min: 22,
                      max: 42,
                      divisions: 10,
                      semanticFormatterCallback: (value) =>
                          'حجم الخط ${value.round()}',
                      onChanged: state.setQuranFontSize,
                    ),
                    const SizedBox(height: 32),
                    Text.rich(
                      QuranPresentation(
                        state.repository.surah(112).ayahs.first,
                      ).span(
                        TextStyle(
                          fontFamily: 'Warsh',
                          fontSize: state.quranFontSize,
                          height: 1.65,
                          color: SuwarColors.green,
                        ),
                      ),
                      semanticsLabel: QuranPresentation(
                        state.repository.surah(112).ayahs.first,
                      ).accessibleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Warsh',
                        fontSize: state.quranFontSize,
                        height: 1.65,
                        color: SuwarColors.green,
                      ),
                    ),
                    const SizedBox(height: 48),
                    PrimaryAction(
                      label: 'حفظ الحجم',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _reading(
    BuildContext context,
    String title,
    String subtitle,
    bool active,
  ) => Semantics(
    selected: active,
    enabled: active,
    child: Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: active ? SuwarColors.sage : SuwarColors.paper,
        border: Border.all(color: SuwarColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: headingStyle(context, size: 25)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SuwarColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? SuwarColors.green : null,
              border: Border.all(
                color: active ? SuwarColors.green : SuwarColors.muted,
              ),
            ),
            child: active
                ? const SuwarIcon(
                    SuwarSymbol.check,
                    color: SuwarColors.paper,
                    size: 16,
                  )
                : null,
          ),
        ],
      ),
    ),
  );
}
