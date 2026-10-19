import 'package:flutter/material.dart';
import '../../core/quran_presentation.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../reading/reading_state.dart';

class ReaderAyah extends StatelessWidget {
  const ReaderAyah({
    super.key,
    required this.surahId,
    required this.ayah,
    required this.fontSize,
    this.reading,
    this.highlighted = false,
    this.onCreatePassage,
  });
  final int surahId;
  final Ayah ayah;
  final double fontSize;
  final ReadingState? reading;
  final bool highlighted;
  final VoidCallback? onCreatePassage;

  Future<void> _save(BuildContext context, {required bool bookmark}) async {
    final state = reading!;
    final position = ReadingPosition(surahId: surahId, ayahNumber: ayah.number);
    final wasBookmarked = state.snapshot.bookmarks.contains(position);
    final saved = await (bookmark
        ? state.toggleBookmark(position)
        : state.savePosition(position));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: MediaQuery.sizeOf(context).width > 640
            ? SnackBarBehavior.floating
            : SnackBarBehavior.fixed,
        width: MediaQuery.sizeOf(context).width > 640 ? 608 : null,
        content: Text(
          !saved
              ? state.error ?? 'تعذّر الحفظ. حاول مجددًا.'
              : bookmark
              ? wasBookmarked
                    ? 'أُزيلت علامة الآية'
                    : 'حُفظت علامة الآية'
              : 'حُفظ موضع المتابعة',
        ),
      ),
    );
  }

  void _showTools(BuildContext context, bool bookmarked) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الآية ${displayNumber(ayah.number)}',
                  style: headingStyle(context, size: 26),
                ),
                const SizedBox(height: 16),
                if (reading != null)
                  PrimaryAction(
                    key: ValueKey('continue-$surahId-${ayah.number}'),
                    label: 'تابع من هذه الآية',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _save(context, bookmark: false);
                    },
                  ),
                const SizedBox(height: 12),
                if (reading != null)
                  PrimaryAction(
                    key: ValueKey('bookmark-$surahId-${ayah.number}'),
                    label: bookmarked ? 'إزالة علامة الآية' : 'حفظ علامة للآية',
                    secondary: true,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _save(context, bookmark: true);
                    },
                  ),
                if (onCreatePassage != null) ...[
                  const SizedBox(height: 12),
                  PrimaryAction(
                    label: 'إنشاء مقطع يبدأ بهذه الآية',
                    secondary: true,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onCreatePassage!();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = ReadingPosition(surahId: surahId, ayahNumber: ayah.number);
    final isPosition = reading?.snapshot.position == position;
    final bookmarked = reading?.snapshot.bookmarks.contains(position) ?? false;
    final presentation = QuranPresentation(ayah);
    final style = TextStyle(
      fontFamily: 'Warsh',
      fontSize: fontSize,
      height: 1.65,
      color: SuwarColors.green,
    );
    return Padding(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: presentation.span(style),
            textDirection: TextDirection.rtl,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final needsGutter =
              (reading != null || onCreatePassage != null) &&
              painter.width > constraints.maxWidth - 96;
          painter.dispose();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 57),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: needsGutter ? 48 : 24,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: highlighted || isPosition ? SuwarColors.sage : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Semantics(
                  label:
                      'الآية ${displayNumber(ayah.number)}. ${presentation.accessibleText}',
                  excludeSemantics: true,
                  child: SelectableText.rich(
                    presentation.span(style),
                    key: ValueKey('reader-text-$surahId-${ayah.number}'),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ),
              if (reading != null || onCreatePassage != null)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  width: 48,
                  height: 57,
                  child: Center(
                    child: IconButton(
                      key: ValueKey('reader-menu-$surahId-${ayah.number}'),
                      tooltip: 'أدوات الآية ${displayNumber(ayah.number)}',
                      onPressed: () => _showTools(context, bookmarked),
                      icon: Icon(
                        bookmarked ? Icons.bookmark_border : Icons.more_horiz,
                        size: 16,
                        color: bookmarked
                            ? SuwarColors.goldText
                            : SuwarColors.muted,
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
