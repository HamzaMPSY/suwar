import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../prayer/prayer_city_screen.dart';
import '../prayer/prayer_models.dart';
import '../prayer/prayer_runtime.dart';
import 'onboarding_finish.dart';
import 'onboarding_reminder_setup.dart';
import 'onboarding_steps.dart';

class OnboardingPrayerSetup extends StatefulWidget {
  const OnboardingPrayerSetup({
    super.key,
    required this.state,
    required this.prayer,
  });
  final AppState state;
  final PrayerRuntime prayer;
  @override
  State<OnboardingPrayerSetup> createState() => _OnboardingPrayerSetupState();
}

class _OnboardingPrayerSetupState extends State<OnboardingPrayerSetup> {
  bool busy = false;
  Future<void> _choose() async {
    final city = await Navigator.of(context).push<PrayerCity>(
      MaterialPageRoute(
        builder: (_) =>
            PrayerCityScreen(settings: widget.prayer.state.settings),
      ),
    );
    if (city == null || !mounted) return;
    setState(() => busy = true);
    final saved = await widget.prayer.state.update(
      widget.prayer.state.settings.copyWith(city: city),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.prayer.state.error!)));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OnboardingReminderSetup(state: widget.state, prayer: widget.prayer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          ScreenHeading(
            title: 'صلاتك في وقتها',
            subtitle: 'حدّد مدينتك واضبط تذكيراتك.',
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingSteps(step: 1),
                const SizedBox(height: 39),
                const Center(
                  child: SuwarIcon(
                    SuwarSymbol.pin,
                    size: 50,
                    color: SuwarColors.goldText,
                  ),
                ),
                const SizedBox(height: 19),
                Text(
                  'أين تصلّي؟',
                  textAlign: TextAlign.center,
                  style: headingStyle(context, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'اختر مدينتك لعرض مواقيت الصلاة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SuwarColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 40),
                PrimaryAction(
                  label: busy ? 'جارٍ الحفظ…' : 'اختيار المدينة يدويًا',
                  onPressed: busy ? null : _choose,
                ),
                const SizedBox(height: 14),
                const PrimaryAction(
                  label: 'استخدام موقعي الحالي',
                  secondary: true,
                  onPressed: null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'الموقع التلقائي غير متاح حاليًا. اختر مدينتك يدويًا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SuwarColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    SuwarIcon(SuwarSymbol.prayer, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'تذكير مع سورتين من حفظك',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'سنطلب إذن الإشعارات عند تفعيل التذكير.',
                  style: TextStyle(color: SuwarColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 36),
                PrimaryAction(
                  label: 'متابعة لاحقًا',
                  secondary: true,
                  onPressed: busy
                      ? null
                      : () => finishOnboarding(context, widget.state),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
