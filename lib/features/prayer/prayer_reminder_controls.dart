import '../passages/recitation_target.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/app_state.dart';
import 'prayer_runtime.dart';
import '../../core/widgets.dart';
import 'prayer_models.dart';
import 'prayer_reminders.dart';
import 'prayer_format.dart';
import 'prayer_widgets.dart';

class PrayerReminderControls extends StatelessWidget {
  const PrayerReminderControls({
    super.key,
    required this.settings,
    required this.reminders,
    required this.busy,
    required this.onUpdate,
    required this.onEnable,
    required this.onExact,
    required this.onTest,
    this.onCoverage,
  });
  final PrayerSettings settings;
  final PrayerReminders reminders;
  final bool busy;
  final ValueChanged<PrayerSettings> onUpdate;
  final ValueChanged<bool> onEnable;
  final VoidCallback onExact;
  final VoidCallback onTest;
  final VoidCallback? onCoverage;
  @override
  Widget build(BuildContext context) {
    if (!reminders.supported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PrayerNotice(
            message:
                'التذكيرات متاحة في نسخة Android. تبقى مواقيت الصلاة متاحة هنا.',
          ),
          if (onCoverage != null) ...[
            const SizedBox(height: 16),
            PrimaryAction(
              label: 'حالة التذكيرات',
              secondary: true,
              onPressed: onCoverage,
            ),
          ],
        ],
      );
    }
    final status = !settings.remindersEnabled
        ? 'متوقفة حتى تختار تفعيلها'
        : !reminders.permissionGranted
        ? 'إذن الإشعارات غير مفعّل'
        : reminders.error != null
        ? 'تعذّرت الجدولة؛ راجع التنبيه أدناه'
        : reminders.coverageUntil == null
        ? 'جارٍ إعداد التذكيرات'
        : 'مجدولة بحسب الصلوات المختارة';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('تذكيرات الصلاة', style: TextStyle(fontSize: 16)),
          subtitle: Text(status),
          value: settings.remindersEnabled,
          onChanged: busy ? null : onEnable,
        ),
        if (!reminders.permissionGranted)
          const PrayerNotice(
            message: 'إذن الإشعارات غير مفعّل. سيُطلب منك عند تفعيل التذكيرات.',
          ),
        const SizedBox(height: 12),
        Text(
          'الصلوات التي أريد تذكيرًا بها',
          style: headingStyle(context, size: 23),
        ),
        for (final kind in PrayerKind.values)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(kind.label),
            value: settings.enabledPrayers.contains(kind),
            onChanged: busy
                ? null
                : (value) {
                    final selected = {...settings.enabledPrayers};
                    if (value) {
                      selected.add(kind);
                    } else {
                      selected.remove(kind);
                    }
                    onUpdate(settings.copyWith(enabledPrayers: selected));
                  },
          ),
        if (settings.enabledPrayers.isEmpty)
          const PrayerNotice(
            message: 'اختر صلاة واحدة على الأقل لجدولة تذكير.',
          ),
        const SizedBox(height: 12),
        const Text('توقيت التذكير'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final minutes in [0, 10])
              SuwarChoicePill(
                label: minutes == 0 ? 'عند وقت الصلاة' : 'قبلها بـ 10 دقائق',
                selected: settings.leadMinutes == minutes,
                onTap: busy
                    ? null
                    : () => onUpdate(settings.copyWith(leadMinutes: minutes)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('اقتراح سورتين من حفظي'),
          subtitle: const Text('من محفوظاتك فقط، دون تكرار داخل الاقتراح.'),
          value: settings.includeSuggestions,
          onChanged: busy
              ? null
              : (value) =>
                    onUpdate(settings.copyWith(includeSuggestions: value)),
        ),
        const SizedBox(height: 16),
        PrayerNotice(
          message: reminders.exactAllowed
              ? 'إذن التوقيت الدقيق متاح.'
              : 'قد تتأخر التذكيرات التقريبية. التوقيت الدقيق يحتاج إذنًا إضافيًا من الجهاز.',
          action: reminders.exactAllowed
              ? null
              : TextButton(
                  onPressed: busy ? null : onExact,
                  child: const Text('طلب التوقيت الدقيق'),
                ),
        ),
        const SizedBox(height: 16),
        PrimaryAction(
          label: 'إرسال إشعار تجريبي',
          secondary: true,
          onPressed: busy ? null : onTest,
        ),
        if (onCoverage != null) ...[
          const SizedBox(height: 16),
          PrimaryAction(
            label: 'حالة التذكيرات',
            secondary: true,
            onPressed: busy ? null : onCoverage,
          ),
        ],
        if (settings.remindersEnabled &&
            reminders.error == null &&
            reminders.coverageUntil != null &&
            reminders.permissionGranted) ...[
          const SizedBox(height: 16),
          Text(
            'التذكيرات مجدولة حتى ${prayerDate(reminders.coverageUntil!)}. افتح التطبيق لتجديد الثلاثين يومًا التالية.',
            style: const TextStyle(color: SuwarColors.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

Future<String?> requestPrayerReminderChange(
  PrayerRuntime runtime,
  bool enabled,
) async {
  if (enabled && !await runtime.reminders.requestPermission()) {
    return 'إذن الإشعارات غير مفعّل. تظل المواقيت متاحة دون تذكير.';
  }
  final saved = await runtime.state.update(
    runtime.state.settings.copyWith(remindersEnabled: enabled),
  );
  if (!saved) return runtime.state.error ?? 'تعذّر حفظ التذكيرات.';
  await runtime.reschedule(force: true);
  return null;
}

Future<String> sendPrayerTest(PrayerRuntime runtime, AppState app) async {
  if (!await runtime.reminders.requestPermission()) {
    return 'إذن الإشعارات غير مفعّل.';
  }
  await runtime.reminders.showTest(eligibleRecitations(app, runtime.passages));
  return runtime.reminders.error ?? 'أُرسل إشعار تجريبي إلى الجهاز.';
}
