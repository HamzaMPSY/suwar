import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../prayer/prayer_runtime.dart';
import 'onboarding_finish.dart';
import 'onboarding_steps.dart';

class OnboardingReminderSetup extends StatefulWidget {
  const OnboardingReminderSetup({
    super.key,
    required this.state,
    required this.prayer,
  });
  final AppState state;
  final PrayerRuntime prayer;
  @override
  State<OnboardingReminderSetup> createState() =>
      _OnboardingReminderSetupState();
}

class _OnboardingReminderSetupState extends State<OnboardingReminderSetup> {
  late int lead = widget.prayer.state.settings.leadMinutes;
  bool busy = false, denied = false;
  Future<void> _enable() async {
    if (busy) return;
    setState(() => busy = true);
    final granted = await widget.prayer.reminders.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        busy = false;
        denied = true;
      });
      return;
    }
    final saved = await widget.prayer.state.update(
      widget.prayer.state.settings.copyWith(
        remindersEnabled: true,
        leadMinutes: lead,
      ),
    );
    if (saved) await widget.prayer.reschedule(force: true);
    if (!mounted) return;
    setState(() => busy = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.prayer.state.error!)));
      return;
    }
    await finishOnboarding(context, widget.state);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          ScreenHeading(
            title: denied ? 'الإشعارات غير مفعّلة' : 'تذكيرات الصلاة',
            subtitle: denied
                ? 'يمكنك متابعة المواقيت داخل التطبيق.'
                : '${widget.prayer.state.settings.city.name} · يمكنك تعديل المواقيت لاحقًا.',
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingSteps(step: 2),
                const SizedBox(height: 39),
                if (denied) ...[
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.notifications_none,
                    size: 54,
                    color: SuwarColors.goldText,
                  ),
                  const SizedBox(height: 44),
                  Text(
                    'فعّل الإذن لتصلك التذكيرات',
                    textAlign: TextAlign.center,
                    style: headingStyle(context, size: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.prayer.reminders.supported
                        ? 'إذا رفض الجهاز الإذن، افتح إعدادات الهاتف ثم التطبيقات ثم سُوَر ثم الإشعارات. يمكنك المتابعة دون تذكير.'
                        : 'التذكيرات متاحة في نسخة Android. يمكنك متابعة المواقيت هنا دون إشعارات.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SuwarColors.muted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 44),
                  PrimaryAction(
                    label: 'المحاولة من جديد',
                    onPressed: busy || !widget.prayer.reminders.supported
                        ? null
                        : _enable,
                  ),
                  const SizedBox(height: 16),
                  PrimaryAction(
                    label: 'متابعة دون إشعارات',
                    secondary: true,
                    onPressed: busy
                        ? null
                        : () => finishOnboarding(context, widget.state),
                  ),
                ] else ...[
                  Container(
                    constraints: const BoxConstraints(minHeight: 178),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: SuwarColors.sage,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 44,
                          color: SuwarColors.green,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'موعد الصلاة، ومعه اقتراحك',
                          textAlign: TextAlign.center,
                          style: headingStyle(context, size: 21),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'سورتان عشوائيتان من السور التي تحفظها.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SuwarColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'توقيت التذكير',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SuwarChoicePill(
                        label: 'عند الأذان',
                        selected: lead == 0,
                        width: 130,
                        onTap: busy ? null : () => setState(() => lead = 0),
                      ),
                      SuwarChoicePill(
                        label: 'قبلها بـ 10 دقائق',
                        selected: lead == 10,
                        width: 196,
                        onTap: busy ? null : () => setState(() => lead = 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  const Text(
                    'لا تحتاج إلى حساب. حفظك يبقى على جهازك.',
                    style: TextStyle(color: SuwarColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 65),
                  if (!widget.prayer.reminders.supported)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'التذكيرات متاحة في نسخة Android. يمكنك متابعة المواقيت هنا دون إشعارات.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SuwarColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  PrimaryAction(
                    label: busy ? 'جارٍ التفعيل…' : 'تفعيل الإشعارات',
                    onPressed: busy || !widget.prayer.reminders.supported
                        ? null
                        : _enable,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => finishOnboarding(context, widget.state),
                    child: const Text('ليس الآن'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
