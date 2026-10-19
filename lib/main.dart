import 'package:flutter/material.dart';
import 'app.dart';
import 'core/personal_session.dart';
import 'core/theme.dart';
import 'features/backup/backup_codec.dart';
import 'features/backup/backup_journal.dart';
import 'features/backup/backup_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<PersonalSession> future = PersonalSession.load();
  bool restoring = false;
  String? notice;

  Future<void> restore(PersonalSession old, BackupBundle bundle) async {
    if (restoring) return;
    setState(() => restoring = true);
    // Unmount every editor before flushing, so none can enqueue stale writes.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await old.shutdown();
      await BackupJournal.apply(old.preferences, bundle);
      notice =
          'اكتملت الاستعادة. تنبيهات الصلاة متوقفة؛ يمكنك تفعيلها من إعدادات الصلاة.';
    } catch (_) {
      notice = 'تعذّرت الاستعادة. ستُستعاد البيانات السابقة قبل فتح التطبيق.';
    }
    final next = PersonalSession.load();
    if (mounted) {
      setState(() {
        future = next;
        restoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PersonalSession>(
    future: future,
    builder: (context, snapshot) {
      if (!restoring &&
          snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        final session = snapshot.data!;
        return SuwarApp(
          key: ObjectKey(session),
          state: session.app,
          prayer: session.prayer,
          audio: session.audio,
          reading: session.reading,
          passages: session.passages,
          revision: session.revision,
          personal: BackupService(
            app: session.app,
            prayer: session.prayer.state,
            reading: session.reading,
            passages: session.passages,
            revision: session.revision,
            widget: session.widget,
            restore: (bundle) => restore(session, bundle),
          ),
          notice: notice,
          onDismissNotice: () => setState(() => notice = null),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: suwarTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: !restoring && snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تعذّر فتح بياناتك بأمان. حاول مرة أخرى.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                setState(() => future = PersonalSession.load()),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'جارٍ فتح المصحف',
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
