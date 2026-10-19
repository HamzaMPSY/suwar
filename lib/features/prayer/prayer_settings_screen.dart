import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_runtime.dart';
import 'prayer_models.dart';
import 'prayer_city_screen.dart';
import 'prayer_coverage_screen.dart';
import 'prayer_widgets.dart';
import 'prayer_location_controls.dart';
import 'prayer_reminder_controls.dart';

enum PrayerSettingsSection { summary, calculation, reminders }

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({
    super.key,
    required this.runtime,
    required this.app,
    this.section = PrayerSettingsSection.summary,
  });
  final PrayerRuntime runtime;
  final AppState app;
  final PrayerSettingsSection section;
  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  bool busy = false;
  Future<void> _save(PrayerSettings settings) async {
    if (busy) return;
    setState(() => busy = true);
    await widget.runtime.state.update(settings);
    if (mounted) setState(() => busy = false);
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _enable(bool enabled) async {
    if (busy) return;
    setState(() => busy = true);
    final message = await requestPrayerReminderChange(widget.runtime, enabled);
    if (!mounted) return;
    setState(() => busy = false);
    if (message != null) _message(message);
  }

  Future<void> _test() async {
    if (busy) return;
    setState(() => busy = true);
    final message = await sendPrayerTest(widget.runtime, widget.app);
    if (!mounted) return;
    setState(() => busy = false);
    _message(message);
  }

  Future<void> _finish() async {
    if (busy) return;
    setState(() => busy = true);
    await widget.runtime.state.flush();
    await widget.runtime.reschedule(force: true);
    if (!mounted) return;
    setState(() => busy = false);
    if (widget.runtime.state.error == null) Navigator.of(context).pop();
  }

  void _open(PrayerSettingsSection section) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PrayerSettingsScreen(
        runtime: widget.runtime,
        app: widget.app,
        section: section,
      ),
    ),
  );
  Future<void> _city() async {
    final city = await Navigator.of(context).push<PrayerCity>(
      MaterialPageRoute(
        builder: (_) =>
            PrayerCityScreen(settings: widget.runtime.state.settings),
      ),
    );
    if (city != null && mounted) {
      await _save(widget.runtime.state.settings.copyWith(city: city));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.runtime.state,
          widget.runtime.reminders,
        ]),
        builder: (context, _) {
          final state = widget.runtime.state;
          final settings = state.settings;
          final reminders = widget.runtime.reminders;
          final summary = widget.section == PrayerSettingsSection.summary;
          final calculation =
              widget.section == PrayerSettingsSection.calculation;
          return ListView(
            children: [
              ScreenHeading(
                title: summary || calculation
                    ? 'إعدادات الصلاة'
                    : 'تذكيرات الصلاة',
                subtitle: summary
                    ? 'اضبط التذكيرات بحسب يومك.'
                    : calculation
                    ? 'مدينتك، وطريقة الحساب، وتذكيراتك'
                    : 'الصلوات، والتوقيت، وما يظهر في الإشعار',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (summary) ...[
                      const SizedBox(height: 13),
                      prayerSettingsRow(
                        'المدينة',
                        '${settings.city.name}، المغرب',
                        busy ? null : _city,
                      ),
                      prayerSettingsRow(
                        'طريقة حساب المواقيت',
                        settings.method.label,
                        busy
                            ? null
                            : () => _open(PrayerSettingsSection.calculation),
                      ),
                      prayerSettingsRow(
                        'توقيت التذكير',
                        settings.leadMinutes == 0
                            ? 'عند دخول وقت الصلاة'
                            : 'قبلها بـ 10 دقائق',
                        busy
                            ? null
                            : () => _open(PrayerSettingsSection.reminders),
                      ),
                      const SizedBox(height: 26),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'اقتراح سورتين من حفظي',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: settings.includeSuggestions,
                        onChanged: busy
                            ? null
                            : (value) => _save(
                                settings.copyWith(includeSuggestions: value),
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'اختيار عشوائي دون تكرار داخل الاقتراح.',
                        style: TextStyle(
                          color: SuwarColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 84),
                      PrimaryAction(
                        label: busy ? 'جارٍ الحفظ…' : 'حفظ الإعدادات',
                        onPressed: busy ? null : _finish,
                      ),
                    ] else if (calculation) ...[
                      const SizedBox(height: 24),
                      PrayerLocationControls(
                        settings: settings,
                        busy: busy,
                        onUpdate: _save,
                      ),
                      const SizedBox(height: 64),
                      PrimaryAction(
                        label: 'تذكيرات الصلاة',
                        onPressed: () => _open(PrayerSettingsSection.reminders),
                      ),
                      const SizedBox(height: 16),
                      PrimaryAction(
                        label: 'العودة إلى المواقيت',
                        secondary: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      PrayerReminderControls(
                        settings: settings,
                        reminders: reminders,
                        busy: busy,
                        onUpdate: _save,
                        onEnable: _enable,
                        onTest: _test,
                        onCoverage: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PrayerCoverageScreen(
                              runtime: widget.runtime,
                              app: widget.app,
                            ),
                          ),
                        ),
                        onExact: () async {
                          if (busy) return;
                          setState(() => busy = true);
                          await reminders.requestExactPermission();
                          await widget.runtime.refresh();
                          if (mounted) setState(() => busy = false);
                        },
                      ),
                    ],
                    if (state.error != null) ...[
                      const SizedBox(height: 16),
                      PrayerNotice(
                        message: state.error!,
                        icon: Icons.error_outline,
                      ),
                    ],
                    if (reminders.error != null) ...[
                      const SizedBox(height: 16),
                      PrayerNotice(
                        message: reminders.error!,
                        icon: Icons.error_outline,
                        action: TextButton(
                          onPressed: busy
                              ? null
                              : () => widget.runtime.refresh(),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
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
