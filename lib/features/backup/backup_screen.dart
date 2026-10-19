import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../core/theme.dart';
import '../prayer/prayer_widgets.dart';
import 'backup_codec.dart';
import 'backup_files.dart';
import 'backup_preview.dart';
import 'backup_scope.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final scroll = ScrollController();
  bool busy = false;
  BackupBundle? preview;
  String? message, error;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _top() async {
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _cancelPreview() async {
    setState(() {
      preview = null;
      message = error = null;
    });
    await _top();
  }

  void _start() => setState(() {
    busy = true;
    message = error = null;
  });

  void _fail(String value) {
    if (!mounted) return;
    setState(() => error = value);
  }

  Future<void> _export() async {
    if (busy) return;
    final service = BackupScope.of(context);
    _start();
    try {
      await service.flush();
      if (!mounted) return;
      final bundle = BackupCodec.capture(
        service.app,
        service.prayer,
        service.reading,
        service.revision,
        passages: service.passages,
      );
      final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final saved = await saveBackupFile(
        'suwar-backup-$date.json',
        bundle.encode(),
      );
      if (mounted && saved) {
        setState(
          () => message = kIsWeb
              ? 'بدأ تنزيل ملف النسخة. تحقّق من مجلد التنزيلات في المتصفح.'
              : 'حُفظت النسخة في المكان الذي اخترته.',
        );
      }
    } catch (_) {
      _fail('تعذّر حفظ النسخة. تحقّق من المساحة وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _choose() async {
    if (busy) return;
    final service = BackupScope.of(context);
    _start();
    try {
      final text = await openBackupFile();
      if (text == null || !mounted) return;
      final bundle = BackupCodec.decode(text, service.app.repository);
      setState(() => preview = bundle);
      await _top();
    } catch (_) {
      _fail('تعذّر فتح النسخة. اختر ملف سُوَر صالحًا بحجم لا يتجاوز 2 م.ب.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    if (busy || preview == null) return;
    final service = BackupScope.of(context);
    final bundle = preview!;
    _start();
    try {
      await service.restore(bundle);
      // Restoring may replace the entire application and dispose this route.
      if (mounted) {
        setState(() {
          preview = null;
          message = 'اكتملت الاستعادة. تذكيرات الصلاة متوقفة حتى تعيد تفعيلها.';
        });
      }
    } catch (_) {
      _fail('لم تكتمل الاستعادة. أعد فتح التطبيق قبل المحاولة مجددًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        controller: scroll,
        children: [
          ScreenHeading(
            title: preview == null ? 'نسخة احتياطية' : 'معاينة النسخة',
            subtitle: preview == null
                ? 'احفظ تقدّمك في ملف تختاره'
                : 'راجع البيانات قبل الاستعادة',
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 33, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (preview == null)
                  ..._actions()
                else
                  BackupPreview(
                    bundle: preview!,
                    busy: busy,
                    onRestore: _restore,
                    onCancel: _cancelPreview,
                  ),
                if (busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    semanticsLabel: 'جارٍ تنفيذ العملية',
                  ),
                ],
                if (message != null || error != null) ...[
                  const SizedBox(height: 20),
                  PrayerNotice(
                    message: error ?? message!,
                    icon: error == null
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> _actions() => [
    const DesignNotice(
      minHeight: 150,
      message:
          'تشمل النسخة سورك ومقاطعك المحفوظة، موضعك، علاماتك، مراجعتك وإعدادات الصلاة. لا تشمل ملفات التلاوة أو أذونات الجهاز.',
    ),
    const SizedBox(height: 60),
    PrimaryAction(
      label: 'تصدير نسخة إلى ملف',
      onPressed: busy ? null : _export,
    ),
    const SizedBox(height: 24),
    PrimaryAction(
      label: 'اختيار ملف للاستعادة',
      secondary: true,
      backgroundColor: SuwarColors.paper,
      onPressed: busy ? null : _choose,
    ),
    const SizedBox(height: 64),
    const DesignNotice(
      minHeight: 120,
      message:
          'لن نستبدل البيانات قبل معاينة الملف وتأكيد الاستعادة. احتفظ بالملف في مكان تثق به.',
    ),
  ];
}
