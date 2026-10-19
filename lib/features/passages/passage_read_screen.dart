import 'package:flutter/material.dart';
import '../../core/quran_presentation.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_models.dart';

/// A bounded, read-only view: never alters whole-surah learning or reading position.
class PassageReadScreen extends StatelessWidget {
  const PassageReadScreen({
    super.key,
    required this.app,
    required this.range,
    this.name,
  });
  final AppState app;
  final PassageRange range;
  final String? name;
  @override
  Widget build(BuildContext context) => PassageTextView(
    app: app,
    range: range,
    name: name,
    actionLabel: 'العودة إلى المقطع',
    onAction: () => Navigator.of(context).pop(),
    footer: 'رواية ورش عن نافع',
  );
}

/// Preview and reading share exact text with a fixed header/action at ordinary sizes.
class PassageTextView extends StatelessWidget {
  const PassageTextView({
    super.key,
    required this.app,
    required this.range,
    this.name,
    required this.actionLabel,
    required this.onAction,
    this.footer,
  });
  final AppState app;
  final PassageRange range;
  final String? name;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? footer;

  TextStyle get _style => TextStyle(
    fontFamily: 'Warsh',
    fontSize: app.quranFontSize,
    height: 1.78,
    color: SuwarColors.green,
  );

  Widget _ayah(Ayah ayah) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Semantics(
      label:
          'الآية ${displayNumber(ayah.number)}. ${QuranPresentation(ayah).accessibleText}',
      excludeSemantics: true,
      child: SelectableText.rich(
        QuranPresentation(ayah).span(_style),
        key: ValueKey('passage-ayah-${range.surahId}-${ayah.number}'),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: _style,
      ),
    ),
  );

  Widget _body(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final verses = range.ayahs(app.repository);
      var height = 25.0;
      for (final verse in verses) {
        final painter = TextPainter(
          text: QuranPresentation(verse).span(_style),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: bounds.maxWidth - 48);
        height += painter.height + 24;
        painter.dispose();
      }
      final overflow = height > bounds.maxHeight;
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('passage-scripture'),
              padding: const EdgeInsets.fromLTRB(24, 25, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final ayah in verses) _ayah(ayah)],
              ),
            ),
          ),
          if (overflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Text(
                'مرّر لقراءة المقطع كاملًا',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: SuwarColors.muted),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final title = name?.trim();
    final heading = ScreenHeading(
      title: title == null || title.isEmpty ? 'معاينة المقطع' : title,
      subtitle: range.reference(app.repository),
      onBack: () => Navigator.of(context).pop(),
    );
    final media = MediaQuery.of(context);
    final flexibleHeader =
        media.size.height - media.viewInsets.bottom < 640 ||
        media.textScaler.scale(14) > 21 ||
        (title?.runes.length ?? 0) > 60;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!flexibleHeader) heading,
            Expanded(
              child: flexibleHeader
                  ? ListView(
                      key: const PageStorageKey('passage-accessible-preview'),
                      children: [
                        heading,
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final ayah in range.ayahs(app.repository))
                                _ayah(ayah),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _body(context),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 27),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryAction(label: actionLabel, onPressed: onAction),
                  if (footer != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      footer!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SuwarColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
