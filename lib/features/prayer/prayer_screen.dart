import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_runtime.dart';
import 'prayer_format.dart';
import 'prayer_widgets.dart';
import 'prayer_settings_screen.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key, required this.runtime, required this.app});
  final PrayerRuntime runtime;
  final AppState app;
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _settings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PrayerSettingsScreen(runtime: widget.runtime, app: widget.app),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.runtime.state,
      widget.runtime.reminders,
    ]),
    builder: (context, _) {
      final state = widget.runtime.state;
      final settings = state.settings;
      final now = DateTime.now().toUtc();
      final local = state.calculator.localNow(settings, now);
      final next = state.calculator.next(settings, now);
      final prayers = state.calculator.day(settings, local);
      final reminders = widget.runtime.reminders;
      final active =
          settings.remindersEnabled &&
          reminders.permissionGranted &&
          reminders.error == null &&
          reminders.coverageUntil != null;
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.35;
      return ListView(
        children: [
          ScreenHeading(
            title: 'مواقيت الصلاة',
            subtitle: '${settings.city.name} · ${prayerDate(local)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SuwarChoicePill(
                    label: 'اليوم',
                    selected: true,
                    width: 102,
                    onTap: null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'الصلاة القادمة: ${next.kind.label}',
                  style: const TextStyle(
                    color: SuwarColors.green,
                    fontSize: 18,
                    height: 1.65,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 27),
                for (final prayer in prayers) ...[
                  Material(
                    color: prayer.timeUtc == next.timeUtc
                        ? SuwarColors.sage
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _settings,
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 68),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 11,
                            top: 6,
                            bottom: 6,
                          ),
                          child: large
                              ? Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      prayer.kind.label,
                                      style: headingStyle(context, size: 25),
                                    ),
                                    Text(
                                      prayerClock(
                                        state.calculator.localTime(
                                          settings,
                                          prayer.timeUtc,
                                        ),
                                      ),
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        color: SuwarColors.green,
                                      ),
                                    ),
                                    Icon(
                                      Icons.notifications_none,
                                      size: 22,
                                      color:
                                          active &&
                                              settings.enabledPrayers.contains(
                                                prayer.kind,
                                              )
                                          ? SuwarColors.green
                                          : SuwarColors.muted,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        prayer.kind.label,
                                        style: headingStyle(context, size: 25),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        prayerClock(
                                          state.calculator.localTime(
                                            settings,
                                            prayer.timeUtc,
                                          ),
                                        ),
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 21,
                                          color: SuwarColors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.notifications_none,
                                      size: 22,
                                      color:
                                          active &&
                                              settings.enabledPrayers.contains(
                                                prayer.kind,
                                              )
                                          ? SuwarColors.green
                                          : SuwarColors.muted,
                                      semanticLabel:
                                          active &&
                                              settings.enabledPrayers.contains(
                                                prayer.kind,
                                              )
                                          ? 'التذكير مفعّل'
                                          : 'التذكير متوقف',
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 19),
                PrimaryAction(
                  label: 'إعدادات المواقيت والتذكيرات',
                  minimumHeight: 48,
                  verticalPadding: 10,
                  secondary: true,
                  onPressed: _settings,
                ),
                const SizedBox(height: 24),
                Text(
                  'مواقيت محسوبة · ${settings.method.label}',
                  style: const TextStyle(
                    color: SuwarColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (settings.remindersEnabled &&
                    !reminders.permissionGranted) ...[
                  const PrayerNotice(
                    message:
                        'إذن الإشعارات غير مفعّل. تظل المواقيت متاحة دون تذكير.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.error != null) PrayerNotice(message: state.error!),
                if (reminders.error != null)
                  PrayerNotice(message: reminders.error!),
                if (active && reminders.coverageUntil != null)
                  Text(
                    'مجدولة حتى ${prayerDate(reminders.coverageUntil!)}. افتح التطبيق لتجديدها.',
                    style: const TextStyle(
                      color: SuwarColors.muted,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      );
    },
  );
}
