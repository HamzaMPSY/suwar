import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../backup/backup_scope.dart';
import '../backup/backup_screen.dart';
import '../reading/bookmarks_screen.dart';
import '../reading/reading_scope.dart';
import '../revision/revision_scope.dart';
import '../revision/revision_screen.dart';
import '../prayer/prayer_widget_screen.dart';
import 'settings_screen.dart';

class PersonalSettingsActions extends StatelessWidget {
  const PersonalSettingsActions({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final reading = ReadingScope.maybeOf(context);
    final revision = RevisionScope.maybeOf(context);
    final services = BackupScope.maybeOf(context);
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reading != null)
          SettingsEntry(
            title: 'علاماتي وموضعي',
            value: 'متابعة القراءة والعلامات المحفوظة',
            onTap: () => open(BookmarksScreen(app: app)),
          ),
        if (revision != null)
          SettingsEntry(
            title: 'مراجعتي اليومية',
            value: 'خطة قصيرة من محفوظاتي',
            onTap: () => open(RevisionScreen(state: revision)),
          ),
        if (services != null) ...[
          SettingsEntry(
            title: 'نسخة احتياطية واستعادة',
            value: 'تصدير التقدم أو معاينة ملف محفوظ',
            onTap: () => open(const BackupScreen()),
          ),
          SettingsEntry(
            title: 'أداة الصلاة على الشاشة الرئيسية',
            value: 'موعد الصلاة القادمة وآخر تحديث',
            onTap: () => open(
              PrayerWidgetScreen(
                prayer: services.prayer,
                bridge: services.widget,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
