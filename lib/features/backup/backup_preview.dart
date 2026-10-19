import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../prayer/prayer_format.dart';
import 'backup_codec.dart';
import 'backup_scope.dart';

class BackupPreview extends StatelessWidget {
  const BackupPreview({
    super.key,
    required this.bundle,
    required this.busy,
    required this.onRestore,
    required this.onCancel,
  });
  final BackupBundle bundle;
  final bool busy;
  final VoidCallback onRestore, onCancel;
  @override
  Widget build(BuildContext context) {
    final service = BackupScope.of(context), position = bundle.reading.position;
    final created = service.prayer.calculator.localTime(
      service.prayer.settings,
      bundle.createdUtc,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: Text(
            'ملخص البيانات من الملف المختار',
            style: headingStyle(context, size: 23),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المحفوظات: ${displayNumber(bundle.memorizedCount)} · العلامات: ${displayNumber(bundle.reading.bookmarks.length)}',
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              Text(
                'المقاطع: ${displayNumber(bundle.passages.passages.length)}',
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              Text(
                position == null
                    ? 'لا يوجد موضع قراءة محفوظ'
                    : 'سورة ${service.app.repository.surah(position.surahId).name} · الآية ${displayNumber(position.ayahNumber)}',
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              Text(
                'خطة المراجعة: ${displayNumber(bundle.revision.selected.length)} سورة · ${bundle.prayer.city.name}',
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              Text(
                '${prayerDate(created)} · ${bundle.prayer.method.label}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: SuwarColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (bundle.legacyWithoutPassages) ...[
          const SizedBox(height: 20),
          const DesignNotice(
            message:
                'هذه نسخة قديمة لا تحتوي على مقاطع. ستُزال مقاطعك الحالية عند تأكيد الاستعادة.',
          ),
        ],
        const SizedBox(height: 50),
        const DesignNotice(
          minHeight: 150,
          message:
              'ستستبدل هذه البيانات تقدّمك الحالي وإعداداتك. تبقى التلاوات على جهازك. ستتوقف تذكيرات الصلاة حتى تعيد تفعيلها.',
        ),
        const SizedBox(height: 45),
        PrimaryAction(
          label: 'تأكيد استعادة النسخة',
          onPressed: busy ? null : onRestore,
        ),
        const SizedBox(height: 24),
        PrimaryAction(
          label: 'إلغاء دون تغيير',
          secondary: true,
          backgroundColor: SuwarColors.paper,
          onPressed: busy ? null : onCancel,
        ),
      ],
    );
  }
}
