import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_add_screen.dart';
import 'passage_detail_screen.dart';
import 'passage_models.dart';
import 'passage_scope.dart';
import 'passage_widgets.dart';

class PassagesScreen extends StatelessWidget {
  const PassagesScreen({
    super.key,
    required this.app,
    this.embedded = false,
    this.onShowSurahs,
  });
  final AppState app;
  final bool embedded;
  final VoidCallback? onShowSurahs;
  Future<void> _add(BuildContext context) async {
    final result = await Navigator.push<SavedPassage>(
      context,
      MaterialPageRoute(builder: (_) => PassageAddScreen(app: app)),
    );
    if (result != null && context.mounted) _open(context, result);
  }

  void _open(BuildContext context, SavedPassage p) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PassageDetailScreen(app: app, passageId: p.id),
    ),
  );
  String _count(int n) => switch (n) {
    0 => 'لا مقاطع محفوظة بعد',
    1 => 'مقطع محفوظ',
    2 => 'مقطعان محفوظان',
    _ => '${displayNumber(n)} مقاطع محفوظة',
  };
  @override
  Widget build(BuildContext context) {
    final state = PassageScope.of(context);
    final content = ListenableBuilder(
      listenable: Listenable.merge([state, app]),
      builder: (context, _) {
        final passages = state.snapshot.passages;
        final known = passages.where((p) => p.memorized).length;
        return ListView(
          key: const PageStorageKey('passages'),
          children: [
            ScreenHeading(
              title: 'حفظي',
              subtitle: 'ما تحفظه من السور والآيات',
              onBack: embedded ? null : () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onShowSurahs != null) ...[
                    MemorySectionTabs(
                      passages: true,
                      onChanged: (value) {
                        if (!value) onShowSurahs!();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    '${displayNumber(app.memorizedIds.length)} سورة كاملة · ${passages.isEmpty ? 'لا مقاطع بعد' : _count(known)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: SuwarColors.green,
                    ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DesignNotice(message: state.error!),
                    ),
                  if (passages.isEmpty) ...[
                    const SizedBox(height: 58),
                    const Center(
                      child: Rosette(size: 64, color: SuwarColors.goldText),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ابدأ بآية تعرفها',
                      textAlign: TextAlign.center,
                      style: headingStyle(context, size: 30),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'احفظ آية أو مقطعًا من سورة طويلة، وسمّه بما يسهل عليك تذكّره.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: SuwarColors.muted),
                    ),
                    const SizedBox(height: 48),
                    PrimaryAction(
                      label: 'إضافة أول مقطع',
                      onPressed: () => _add(context),
                    ),
                  ] else ...[
                    const SizedBox(height: 22),
                    for (final p in passages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PassageRow(
                          title: p.displayName(app.repository),
                          reference: p.range.reference(
                            app.repository,
                            includeNarration: false,
                          ),
                          status: !p.memorized
                              ? 'لم أحفظه بعد'
                              : p.includeInPrayer
                              ? 'محفوظ · ضمن اقتراحات الصلاة'
                              : 'محفوظ · غير مضمّن في الاقتراحات',
                          memorized: p.memorized,
                          included: p.includeInPrayer,
                          onTap: () => _open(context, p),
                        ),
                      ),
                    const SizedBox(height: 20),
                    PrimaryAction(
                      label: 'إضافة مقطع',
                      onPressed: () => _add(context),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
    return embedded ? content : Scaffold(body: SafeArea(child: content));
  }
}
