import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_format.dart';
import 'prayer_runtime.dart';
import 'prayer_widgets.dart';
import 'reminder_payload.dart';

class PrayerCoverageScreen extends StatefulWidget {
  const PrayerCoverageScreen({
    super.key,
    required this.runtime,
    required this.app,
  });
  final PrayerRuntime runtime;
  final AppState app;
  @override
  State<PrayerCoverageScreen> createState() => _PrayerCoverageScreenState();
}

class _PrayerCoverageScreenState extends State<PrayerCoverageScreen> {
  bool busy = false;

  Future<void> _exact() async {
    if (busy) return;
    setState(() => busy = true);
    await widget.runtime.reminders.requestExactPermission();
    await widget.runtime.refresh();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.runtime.state,
          widget.runtime.reminders,
          widget.app,
        ]),
        builder: (context, _) {
          final reminders = widget.runtime.reminders;
          final settings = widget.runtime.state.settings;
          final subtitle = !reminders.supported
              ? 'التذكيرات متاحة في نسخة Android'
              : !reminders.permissionGranted
              ? 'إذن الإشعارات غير مفعّل'
              : reminders.exactAllowed
              ? 'إذن الإشعارات متاح · توقيت دقيق'
              : 'إذن الإشعارات متاح · توقيت تقريبي';
          final timing = !reminders.supported
              ? 'تبقى مواقيت الصلاة متاحة هنا. استخدم نسخة Android لتفعيل التذكيرات.'
              : !reminders.permissionGranted
              ? 'إذن الإشعارات غير مفعّل. يمكنك تفعيله من إعدادات التذكيرات. تظل المواقيت متاحة دون تذكير.'
              : reminders.exactAllowed
              ? 'إذن التوقيت الدقيق متاح. تُجدول التذكيرات بحسب الصلوات والتوقيت اللذين اخترتهما.'
              : 'قد تتأخر التذكيرات التقريبية. التوقيت الدقيق يحتاج إذنًا إضافيًا من الجهاز.';
          final known = widget.app.repository.surahs
              .where((surah) => widget.app.memorizedIds.contains(surah.number))
              .take(2)
              .toList();
          final next = widget.runtime.state.calculator.next(
            settings,
            DateTime.now().toUtc(),
          );
          final covered =
              reminders.supported &&
              reminders.permissionGranted &&
              settings.remindersEnabled &&
              settings.enabledPrayers.isNotEmpty &&
              reminders.coverageUntil != null &&
              reminders.error == null;
          final coverage =
              reminders.error ??
              (covered
                  ? 'التذكيرات مجدولة حتى ${prayerDate(widget.runtime.state.calculator.localTime(settings, reminders.coverageUntil!))}. افتح التطبيق لتجديد الثلاثين يومًا التالية.'
                  : 'لا توجد تغطية مؤكدة لتذكيرات مجدولة حاليًا. راجع تفعيل التذكيرات، وإذن الإشعارات، والصلوات المختارة في الإعدادات.');
          return ListView(
            children: [
              ScreenHeading(
                title: 'حالة التذكيرات',
                subtitle: subtitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 120),
                      child: PrayerNotice(message: timing),
                    ),
                    const SizedBox(height: 24),
                    PrimaryAction(
                      label: reminders.exactAllowed
                          ? 'التوقيت الدقيق متاح'
                          : 'طلب التوقيت الدقيق',
                      secondary: true,
                      onPressed:
                          busy ||
                              !reminders.supported ||
                              !reminders.permissionGranted ||
                              reminders.exactAllowed
                          ? null
                          : _exact,
                    ),
                    const SizedBox(height: 44),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 50),
                      child: Text(
                        'اقتراحات من محفوظاتك',
                        style: headingStyle(context, size: 27),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      constraints: const BoxConstraints(minHeight: 130),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: SuwarColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SuwarColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'معاينة تذكير صلاة ${next.kind.label}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            settings.includeSuggestions
                                ? reminderSuggestionText(known)
                                : 'اقتراحات المحفوظات غير مفعّلة في تذكيراتك.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: const Text(
                        'معاينة فقط · لم يُرسل إشعار',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: SuwarColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 132),
                      child: PrayerNotice(message: coverage),
                    ),
                    const SizedBox(height: 28),
                    PrimaryAction(
                      label: 'العودة إلى الإعدادات',
                      secondary: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 10),
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
