import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_presentation.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../quran/reader_screen.dart';
import 'ayah_widget.dart';

class AyahWidgetScreen extends StatefulWidget {
  const AyahWidgetScreen({super.key, required this.app});
  final AppState app;
  @override
  State<AyahWidgetScreen> createState() => _AyahWidgetScreenState();
}

class _AyahWidgetScreenState extends State<AyahWidgetScreen>
    with WidgetsBindingObserver {
  AyahWidgetBridge get bridge => widget.app.ayahWidget;
  bool busy = false;
  String? notice;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(bridge.initialize());
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(bridge.refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void read(RemembranceAyah item) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        state: widget.app,
        surah: widget.app.repository.surah(item.surahId),
        initialAyahNumber: item.ayahNumber,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: bridge,
        builder: (context, _) {
          final item = bridge.selected();
          return ListView(
            children: [
              ScreenHeading(
                title: 'آية تُطمئنك',
                subtitle: 'لحظة تذكّر على شاشتك',
                onBack: () => Navigator.pop(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item == null && bridge.error == null)
                      const LinearProgressIndicator(
                        semanticsLabel: 'جارٍ تحميل الآيات',
                      ),
                    if (item != null) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: 'قراءة الآية في سياقها',
                        child: InkWell(
                          onTap: () => read(item),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: SuwarColors.paper,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: SuwarColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'سُوَر · ${ayahTopics[item.topic]}',
                                  style: const TextStyle(
                                    color: SuwarColors.muted,
                                    fontSize: 13,
                                    fontFamilyFallback: ['Amiri'],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Semantics(
                                  label: QuranPresentation(
                                    item.source(widget.app.repository),
                                  ).accessibleText,
                                  child: ExcludeSemantics(
                                    child: Text(
                                      QuranPresentation(
                                        item.source(widget.app.repository),
                                      ).lexicalText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Warsh',
                                        fontSize: 28,
                                        height: 1.9,
                                        color: SuwarColors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  item.reference(widget.app.repository),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamilyFallback: ['Amiri'],
                                    color: SuwarColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.context,
                        style: const TextStyle(
                          color: SuwarColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'ما الذي تودّ تذكّره؟',
                      style: headingStyle(context, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in ayahTopics.entries)
                          ChoiceChip(
                            label: Text(topic.value),
                            labelStyle: TextStyle(
                              color: bridge.topic == topic.key
                                  ? SuwarColors.paper
                                  : SuwarColors.green,
                            ),
                            selected: bridge.topic == topic.key,
                            onSelected: busy
                                ? null
                                : (_) =>
                                      perform(() => bridge.setTopic(topic.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'آية جديدة كل يوم، دون اتصال. النصوص من رواية ورش، والاختيار مستقل عن محفوظاتك.',
                      style: TextStyle(color: SuwarColors.muted),
                    ),
                    const SizedBox(height: 24),
                    PrimaryAction(
                      label: 'آية أخرى',
                      secondary: true,
                      onPressed: busy || item == null
                          ? null
                          : () => perform(bridge.next),
                    ),
                    if (item != null)
                      TextButton(
                        onPressed: () => read(item),
                        child: const Text('قراءة الآية في سياقها'),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'إضافة الأداة',
                      style: headingStyle(context, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'iPhone: اضغط مطولًا على شاشة القفل، ثم تخصيص، ثم إضافة أدوات، واختر سُوَر. تتطلب أداة القفل iOS 16 أو أحدث.',
                      style: TextStyle(fontFamilyFallback: ['Amiri']),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Android: أضف «سُوَر · آية تُطمئنك» من قائمة الأدوات. تتاح إضافتها إلى شاشة القفل عندما يدعم هاتفك ذلك؛ وقد تحتاج إلى تخصيص شاشة القفل من إعدادات الجهاز.',
                      style: TextStyle(fontFamilyFallback: ['Amiri']),
                    ),
                    const SizedBox(height: 16),
                    if (bridge.supported && !bridge.isIOS)
                      PrimaryAction(
                        label: 'طلب الإضافة إلى الشاشة الرئيسية',
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                final started = await bridge.requestPin();
                                if (mounted) {
                                  setState(
                                    () => notice = started
                                        ? 'أكمل طلب الإضافة الذي يعرضه الهاتف. إضافة شاشة القفل تتم من إعدادات الجهاز.'
                                        : 'افتح قائمة أدوات الهاتف، ثم اختر سُوَر.',
                                  );
                                }
                              }),
                      ),
                    if (!bridge.supported)
                      const Text(
                        'هذه معاينة. إضافة الأداة متاحة في نسخة الهاتف.',
                        style: TextStyle(color: SuwarColors.muted),
                      ),
                    if (bridge.error != null || notice != null) ...[
                      const SizedBox(height: 16),
                      Text(bridge.error ?? notice!),
                    ],
                    if (bridge.error != null)
                      TextButton(
                        onPressed: () => perform(() async {
                          await bridge.initialize();
                          await bridge.refresh();
                        }),
                        child: const Text('إعادة المحاولة'),
                      ),
                    const SizedBox(height: 32),
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
