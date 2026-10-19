import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_edit_screen.dart';
import 'passage_models.dart';
import 'passage_read_screen.dart';
import 'passage_scope.dart';
import 'recitation_target.dart';
import '../prayer/prayer_review_screen.dart';
import '../prayer/reminder_payload.dart';

class PassageDetailScreen extends StatefulWidget {
  const PassageDetailScreen({
    super.key,
    required this.app,
    required this.passageId,
    this.fromReader = false,
  });
  final AppState app;
  final String passageId;
  final bool fromReader;
  @override
  State<PassageDetailScreen> createState() => _PassageDetailScreenState();
}

class _PassageDetailScreenState extends State<PassageDetailScreen> {
  bool busy = false;
  Future<void> _change(Future<bool> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(SavedPassage passage) async {
    final result = await Navigator.of(context).push<SavedPassage>(
      MaterialPageRoute(
        builder: (_) => PassageEditScreen(app: widget.app, passage: passage),
      ),
    );
    if (result != null && result.id != widget.passageId && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PassageDetailScreen(
            app: widget.app,
            passageId: result.id,
            fromReader: widget.fromReader,
          ),
        ),
      );
    }
  }

  void _suggestions({required SavedPassage passage}) {
    final state = PassageScope.of(context);
    final current = RecitationTarget.passage(passage, widget.app.repository);
    final others =
        eligibleRecitations(
            widget.app,
            state,
          ).where((target) => !target.range.overlaps(current.range)).toList()
          ..shuffle(Random());
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrayerReviewScreen(
          app: widget.app,
          subtitle: 'من السور والمقاطع التي تحفظها',
          tap: ReminderTap(
            prayer: 'test',
            targets: [
              current.reference,
              for (final target in others.take(1)) target.reference,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(SavedPassage passage) async {
    final remove = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RemovePassageScreen(app: widget.app, passage: passage),
      ),
    );
    if (remove != true || !mounted) return;
    final state = PassageScope.of(context);
    setState(() => busy = true);
    final saved = await state.remove(passage.id);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = PassageScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final p = state.find(widget.passageId);
            if (p == null) {
              return ListView(
                children: [
                  ScreenHeading(
                    title: 'المقطع غير متاح',
                    onBack: () => Navigator.pop(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('أُزيل المقطع من قائمتك.'),
                  ),
                ],
              );
            }
            return ListView(
              children: [
                ScreenHeading(
                  title: p.displayName(widget.app.repository),
                  subtitle: p.range.reference(widget.app.repository),
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 7, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(minHeight: 78),
                        decoration: BoxDecoration(
                          color: SuwarColors.sage,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p.memorized
                                  ? Icons.check
                                  : Icons.menu_book_outlined,
                              size: 26,
                              color: SuwarColors.green,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    p.memorized ? 'محفوظ' : 'محفوظ في قائمتي',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: SuwarColors.green,
                                    ),
                                  ),
                                  Text(
                                    p.memorized
                                        ? 'تقييمك لحفظ هذا المقطع'
                                        : 'لم أحدّد أنني أحفظه بعد',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SuwarColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryAction(
                        label: 'قراءة المقطع كاملًا',
                        secondary: true,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PassageReadScreen(
                              app: widget.app,
                              range: p.range,
                              name: p.displayName(widget.app.repository),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 82),
                        child: SwitchListTile.adaptive(
                          activeTrackColor: SuwarColors.green,
                          activeThumbColor: SuwarColors.paper,
                          inactiveTrackColor: SuwarColors.line,
                          inactiveThumbColor: SuwarColors.paper,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'أحفظ هذا المقطع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'يمكنك تغيير تقييمك في أي وقت.',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: p.memorized,
                          onChanged: busy
                              ? null
                              : (value) => _change(
                                  () => state.setMemorized(p.id, value),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 23),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 82),
                        child: SwitchListTile.adaptive(
                          activeTrackColor: SuwarColors.green,
                          activeThumbColor: SuwarColors.paper,
                          inactiveTrackColor: SuwarColors.line,
                          inactiveThumbColor: SuwarColors.paper,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'اقتراحه للصلاة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            p.memorized
                                ? 'يظهر مع السور التي تحفظها.'
                                : 'متاح بعد تحديد المقطع كمحفوظ.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: p.includeInPrayer,
                          onChanged: busy || !p.memorized
                              ? null
                              : (value) => _change(
                                  () => state.setPrayerInclusion(p.id, value),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Text(
                          'لا يغيّر هذا حالة حفظ سورة ${widget.app.repository.surah(p.range.surahId).name} كاملة.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: DesignNotice(message: state.error!),
                        ),
                      const SizedBox(height: 30),
                      PrimaryAction(
                        label: p.memorized && p.includeInPrayer
                            ? 'عرض اقتراحات الصلاة'
                            : widget.fromReader
                            ? 'العودة إلى القراءة'
                            : 'العودة إلى مقاطعي',
                        onPressed: () => p.memorized && p.includeInPrayer
                            ? _suggestions(passage: p)
                            : Navigator.pop(context),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: busy ? null : () => _edit(p),
                              child: const Text('تعديل المقطع'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: busy ? null : () => _remove(p),
                              child: const Text('إزالة'),
                            ),
                          ),
                        ],
                      ),
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
}

class _RemovePassageScreen extends StatelessWidget {
  const _RemovePassageScreen({required this.app, required this.passage});
  final AppState app;
  final SavedPassage passage;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          ScreenHeading(
            title: 'إزالة المقطع؟',
            subtitle: passage.displayName(app.repository),
            onBack: () => Navigator.pop(context, false),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'سيُزال من مقاطعي',
                  textAlign: TextAlign.center,
                  style: headingStyle(context, size: 30),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ستُحذف تسميتك وحالة حفظ هذا المقطع، ويتوقف ظهوره في اقتراحات الصلاة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Text(
                  'يبقى نص القرآن وحفظ السورة كاملة كما هما.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: SuwarColors.muted),
                ),
                const SizedBox(height: 64),
                PrimaryAction(
                  label: 'الاحتفاظ بالمقطع',
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 16),
                PrimaryAction(
                  label: 'إزالة المقطع',
                  secondary: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
