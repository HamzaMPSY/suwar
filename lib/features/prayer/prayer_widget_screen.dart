import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_format.dart';
import 'prayer_state.dart';
import 'prayer_widget.dart';
import 'prayer_widgets.dart';

class PrayerWidgetScreen extends StatefulWidget {
  const PrayerWidgetScreen({
    super.key,
    required this.prayer,
    required this.bridge,
  });
  final PrayerState prayer;
  final PrayerWidgetBridge bridge;
  @override
  State<PrayerWidgetScreen> createState() => _PrayerWidgetScreenState();
}

class _PrayerWidgetScreenState extends State<PrayerWidgetScreen> {
  bool busy = false;
  String? message;
  DateTime? refreshed;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool pin = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    await widget.bridge.publish(widget.prayer);
    if (!mounted) return;
    if (widget.bridge.error == null) {
      refreshed = DateTime.now().toUtc();
      if (pin) {
        final started = await widget.bridge.requestPin();
        if (!mounted) return;
        message = started
            ? 'فُتح طلب الإضافة. أكمل التأكيد على الشاشة الرئيسية.'
            : 'يمكنك إضافتها من قائمة الأدوات: اضغط مطولًا على الشاشة الرئيسية ثم اختر سُوَر.';
      } else {
        message = 'حُفظت مواقيت مدينتك للأداة.';
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.prayer, widget.bridge]),
        builder: (context, _) {
          final state = widget.prayer;
          final settings = state.settings;
          final next = state.calculator.next(settings, DateTime.now().toUtc());
          final local = state.calculator.localTime(settings, next.timeUtc);
          final updated = refreshed == null
              ? null
              : state.calculator.localTime(settings, refreshed!);
          return ListView(
            children: [
              ScreenHeading(
                onBack: () => Navigator.of(context).pop(),
                title: 'الصلاة على شاشتك',
                subtitle: 'أداة للموعد القادم على الشاشة الرئيسية',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                      decoration: BoxDecoration(
                        color: SuwarColors.green,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${settings.city.name} · الصلاة القادمة',
                            style: const TextStyle(
                              color: SuwarColors.ivory,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            children: [
                              Text(
                                next.kind.label,
                                style: headingStyle(
                                  context,
                                  size: 30,
                                  color: SuwarColors.ivory,
                                ),
                              ),
                              Text(
                                prayerClock(local),
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: SuwarColors.ivory,
                                  fontSize: 30,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            updated == null
                                ? 'معاينة للموعد المحسوب الآن'
                                : 'آخر تحديث: ${prayerClock(updated)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: SuwarColors.sage,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 65),
                    const DesignNotice(
                      minHeight: 150,
                      message:
                          'تعرض الأداة الموعد ووقت آخر تحديث. قد يؤخّر Android التحديث. اضغط الأداة لفتح الصلاة أو زر التحديث لتحديث عرضها.',
                    ),
                    const SizedBox(height: 55),
                    if (widget.bridge.supported) ...[
                      PrimaryAction(
                        label: 'طلب إضافة الأداة',
                        onPressed: busy ? null : () => _refresh(pin: true),
                      ),
                      const SizedBox(height: 24),
                      PrimaryAction(
                        label: 'تحديث مواقيت الأداة',
                        secondary: true,
                        backgroundColor: SuwarColors.paper,
                        onPressed: busy ? null : _refresh,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تُحفظ مواقيت الثلاثين يومًا التالية. أكمل تأكيد الإضافة على الشاشة الرئيسية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SuwarColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ] else
                      const PrayerNotice(
                        message:
                            'أداة الشاشة الرئيسية متاحة في نسخة Android. تبقى مواقيت الصلاة متاحة داخل التطبيق هنا.',
                      ),
                    if (busy) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(
                        semanticsLabel: 'جارٍ تحديث الأداة',
                      ),
                    ],
                    if (message != null || widget.bridge.error != null) ...[
                      const SizedBox(height: 20),
                      PrayerNotice(message: widget.bridge.error ?? message!),
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
