import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_catalog.dart';
import 'passage_editor_screen.dart';
import 'passage_models.dart';
import 'passage_widgets.dart';

class PassageAddScreen extends StatelessWidget {
  const PassageAddScreen({super.key, required this.app});
  final AppState app;
  Future<void> _open(
    BuildContext context, {
    String? name,
    PassageRange? range,
  }) async {
    final result = await openPassageEditor(
      context,
      app: app,
      initialName: name,
      surahId: range?.surahId,
      startAyah: range?.startAyah,
      endAyah: range?.endAyah,
    );
    if (result != null && context.mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          ScreenHeading(
            title: 'إضافة مقطع',
            subtitle: 'اختر مقطعًا معروفًا أو حدّد الآيات بنفسك',
            onBack: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: const Text(
                    'مقاطع معروفة',
                    style: TextStyle(fontSize: 13, color: SuwarColors.muted),
                  ),
                ),
                const SizedBox(height: 15),
                for (final (index, preset) in PassageCatalog.presets.indexed)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == PassageCatalog.presets.length - 1
                          ? 0
                          : 12,
                    ),
                    child: PassageRow(
                      title: preset.name,
                      reference: preset.range.reference(
                        app.repository,
                        includeNarration: false,
                      ),
                      status: preset.id == 'end-al-baqara'
                          ? 'يمكنك تسميته مثلًا: ختام البقرة'
                          : 'معاينة النص ثم اختيار الاسم',
                      onTap: () => _open(
                        context,
                        name: preset.name,
                        range: preset.range,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: const Text(
                    'تتبع الأرقام مصحف ورش داخل سُوَر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: SuwarColors.muted),
                  ),
                ),
                const SizedBox(height: 42),
                PrimaryAction(
                  label: 'تحديد آيات بنفسي',
                  onPressed: () => _open(context),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
