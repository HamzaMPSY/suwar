import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../quran/reader_screen.dart';
import '../passages/passage_scope.dart';
import '../passages/passage_read_screen.dart';
import '../passages/recitation_target.dart';
import '../passages/recitation_card.dart';
import '../memory/memory_screen.dart';
import '../quran/library_screen.dart';
import 'prayer_models.dart';
import 'prayer_reminders.dart';

class PrayerReviewScreen extends StatefulWidget {
  const PrayerReviewScreen({
    super.key,
    required this.app,
    required this.tap,
    this.subtitle,
  });
  final AppState app;
  final ReminderTap tap;
  final String? subtitle;
  @override
  State<PrayerReviewScreen> createState() => _PrayerReviewScreenState();
}

class _PrayerReviewScreenState extends State<PrayerReviewScreen> {
  late List<RecitationRef> targets = [...widget.tap.targets];
  bool get passageJourney => targets.any((t) => t.passageId != null);
  String get subtitle {
    if (widget.subtitle != null) return widget.subtitle!;
    for (final kind in PrayerKind.values) {
      if (kind.name == widget.tap.prayer) {
        return '${kind.label} · اقتراح من تذكير سُوَر';
      }
    }
    return 'اقتراحك من تذكير سُوَر';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.app,
          ?PassageScope.maybeOf(context),
        ]),
        builder: (context, _) {
          final passages = PassageScope.maybeOf(context);
          final selected = resolveRecitations(targets, widget.app, passages);
          final surahs = [
            for (final target in selected)
              if (!target.isPassage)
                widget.app.repository.surah(target.range.surahId),
          ];
          final eligible = eligibleRecitations(widget.app, passages);
          if (passageJourney) return _mixed(context, selected, eligible);
          return ListView(
            children: [
              ScreenHeading(
                title: surahs.isEmpty
                    ? 'اختر قراءتك للصلاة'
                    : surahs.length == 1
                    ? 'سورة لصلاتك'
                    : 'سورتان لصلاتك',
                subtitle: subtitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'من السور التي تحفظها',
                      style: headingStyle(context, size: 25),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اقتراح اختياري يساعدك على تنويع قراءتك.',
                      style: TextStyle(color: SuwarColors.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    if (surahs.isEmpty)
                      const EmptyMessage(
                        icon: Icons.menu_book_outlined,
                        title: 'اختر قراءتك للصلاة',
                        message:
                            'لا توجد سور محفوظة في هذا الاقتراح الآن. يمكنك مراجعة محفوظاتك من قسم حفظي.',
                      ),
                    for (final surah in surahs) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: SuwarColors.paper,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: SuwarColors.line),
                        ),
                        child: SurahTile(
                          surah: surah,
                          titleSize: 30,
                          ornamentSize: 50,
                          metadataSize: 13,
                          metadataSuffix: 'محفوظة',
                          minimumHeight: 112,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          trailing: const Icon(
                            Icons.chevron_left,
                            size: 24,
                            color: SuwarColors.green,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReaderScreen(state: widget.app, surah: surah),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (surahs.length == 1)
                      const Text(
                        'هذه السورة المتاحة من الاقتراح في محفوظاتك الآن.',
                        style: TextStyle(color: SuwarColors.muted),
                      ),
                    const SizedBox(height: 36),
                    PrimaryAction(
                      label: 'اقتراح سورتين أخريين',
                      secondary: true,
                      onPressed: eligible.length < 2
                          ? null
                          : () => setState(
                              () => targets = selectRecitations(
                                eligible,
                                Random(),
                              ).map((t) => t.reference).toList(),
                            ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'اختيار عشوائي من محفوظاتك فقط',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SuwarColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      child: const Text(
                        'العودة إلى اليوم',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  void _read(RecitationTarget target) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => target.isPassage
          ? PassageReadScreen(
              app: widget.app,
              range: target.range,
              name: target.name,
            )
          : ReaderScreen(
              state: widget.app,
              surah: widget.app.repository.surah(target.range.surahId),
            ),
    ),
  );

  void _manage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: MemoryScreen(
            state: widget.app,
            initialPassages: true,
            onBrowse: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: SafeArea(child: LibraryScreen(state: widget.app)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _mixed(
    BuildContext context,
    List<RecitationTarget> selected,
    List<RecitationTarget> eligible,
  ) {
    final single = selected.length == 1;
    return ListView(
      children: [
        ScreenHeading(
          title: single ? 'اقتراح لصلاتك' : 'اقتراحات لصلاتك',
          subtitle: 'من السور والمقاطع التي تحفظها',
          onBack: () => Navigator.pop(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                selected.isEmpty
                    ? 'راجع محفوظاتك'
                    : single
                    ? 'اقتراح واحد متاح الآن'
                    : 'اقتراحان من حفظك',
                style: headingStyle(context, size: 25),
              ),
              const SizedBox(height: 36),
              if (selected.isEmpty)
                const DesignNotice(
                  message:
                      'لم يعد هذا الاقتراح متاحًا. ربما أزلت المقطع أو غيّرت آياته أو حالة حفظه. اختر اقتراحًا جديدًا من حفظك.',
                ),
              for (final target in selected) ...[
                RecitationCard(target: target, onTap: () => _read(target)),
                const SizedBox(height: 24),
              ],
              if (single) ...[
                const SizedBox(height: 60),
                const Text(
                  'هذا هو الاقتراح المتاح من حفظك الآن.\nفعّل اقتراح مقطع آخر تحفظه لتنويع اختياراتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: SuwarColors.muted),
                ),
                const SizedBox(height: 76),
                PrimaryAction(
                  label: selected.single.isPassage
                      ? 'مراجعة المقطع'
                      : 'مراجعة السورة',
                  onPressed: () => _read(selected.single),
                ),
                const SizedBox(height: 16),
              ] else if (selected.isNotEmpty) ...[
                const SizedBox(height: 2),
                const Text(
                  'اضغط اقتراحًا لمراجعة نصه.',
                  style: TextStyle(fontSize: 13, color: SuwarColors.muted),
                ),
                const SizedBox(height: 48),
              ],
              PrimaryAction(
                label: 'إدارة مقاطعي',
                secondary: single,
                onPressed: _manage,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: eligible.isEmpty
                    ? null
                    : () => setState(
                        () => targets = selectRecitations(
                          eligible,
                          Random(),
                        ).map((t) => t.reference).toList(),
                      ),
                child: const Text('اقتراح جديد من حفظي'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
