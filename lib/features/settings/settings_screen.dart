import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_downloads_screen.dart';
import '../audio/audio_scope.dart';
import '../onboarding/onboarding_screen.dart';
import '../prayer/prayer_runtime.dart';
import '../prayer/prayer_settings_screen.dart';
import 'personal_settings_actions.dart';
import 'reading_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state, this.prayer});
  final AppState state;
  final PrayerRuntime? prayer;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          children: [
            ScreenHeading(
              title: 'الإعدادات',
              subtitle: 'تجربة تناسبك',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 13),
                  SettingsEntry(
                    title: 'لغة التطبيق',
                    value: 'العربية',
                    onTap: () => _info(
                      context,
                      'لغة التطبيق',
                      'تتوفر هذه النسخة باللغة العربية، مع تنقّل من اليمين إلى اليسار.',
                    ),
                  ),
                  SettingsEntry(
                    title: 'رواية القرآن',
                    value: 'ورش عن نافع',
                    onTap: () =>
                        _open(context, ReadingSettingsScreen(state: state)),
                  ),
                  SettingsEntry(
                    title: 'المواقيت والتذكيرات',
                    value: prayer?.state.settings.city.name ?? 'إعدادات الصلاة',
                    onTap: prayer == null
                        ? () => _info(
                            context,
                            'المواقيت والتذكيرات',
                            'إعدادات الصلاة غير متاحة في هذه الجلسة.',
                          )
                        : () => _open(
                            context,
                            PrayerSettingsScreen(runtime: prayer!, app: state),
                          ),
                  ),
                  SettingsEntry(
                    title: 'حجم النص',
                    value: state.quranFontSize <= 26
                        ? 'صغير'
                        : state.quranFontSize >= 34
                        ? 'كبير'
                        : 'متوسط',
                    onTap: () => _open(
                      context,
                      ReadingSettingsScreen(state: state, fontSettings: true),
                    ),
                  ),
                  SettingsEntry(
                    title: 'المظهر',
                    value: 'فاتح',
                    onTap: () => _info(
                      context,
                      'المظهر',
                      'المظهر العاجي الفاتح هو المظهر المتاح في هذه النسخة.',
                    ),
                  ),
                  SettingsEntry(
                    title: 'التحميل دون إنترنت',
                    value: 'السور والتلاوات',
                    onTap: AudioScope.maybeOf(context) == null
                        ? () => _info(
                            context,
                            'التحميل دون إنترنت',
                            'النص القرآني متاح دون اتصال. التلاوات غير متاحة في هذه الجلسة.',
                          )
                        : () =>
                              _open(context, AudioDownloadsScreen(app: state)),
                  ),
                  const SizedBox(height: 28),
                  Text('حفظك خاص بك', style: headingStyle(context, size: 22)),
                  const SizedBox(height: 4),
                  const Text(
                    'تُحفظ اختياراتك على هذا الجهاز.',
                    style: TextStyle(color: SuwarColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  PersonalSettingsActions(app: state),
                  SettingsEntry(
                    title: 'إدارة محفوظاتي',
                    value: 'تعديل السور التي أحفظها',
                    onTap: () =>
                        _open(context, KnownSelectionScreen(state: state)),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'لا نرسل محفوظاتك إلى أي خادم.\nالنص والخط: مجمع الملك فهد لطباعة المصحف الشريف. بيانات ورش المرفقة محفوظة كما وردت في المصدر.',
                    style: TextStyle(fontSize: 12, color: SuwarColors.muted),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  void _info(BuildContext context, String title, String message) => _open(
    context,
    Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ScreenHeading(
              title: title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(padding: const EdgeInsets.all(24), child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

class SettingsEntry extends StatelessWidget {
  const SettingsEntry({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });
  final String title;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 77),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 34),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: SuwarColors.green,
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 28),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 13,
                                color: SuwarColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const SuwarIcon(SuwarSymbol.back, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      const Divider(),
    ],
  );
}
